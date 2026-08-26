"""Capture sidecar for Tobor bosses.

Godot's WASAPI driver crashes or log-floods on 4-channel laptop mic arrays.
PortAudio MME/DirectSound expose those same arrays as 1–2 channels, so this
process records there and writes WAV/PNG into a shared folder.

Godot talks through files in --dir:
  av_cmd.txt        one command line: start|dump|snap|quit [token]
  av_ack.txt        echo of the handled command
  av_status.json    heartbeat + device flags
  tobor_chant.wav   dump output
  tobor_pose.png    snap output (webcam boss later)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import time
import wave

import numpy as np
import sounddevice as sd

RATE = 16000
MAX_SECONDS = 6.0
STATUS_NAME = "av_status.json"
CMD_NAME = "av_cmd.txt"
ACK_NAME = "av_ack.txt"
WAV_NAME = "tobor_chant.wav"
POSE_NAME = "tobor_pose.png"


def _host_name(device: dict) -> str:
	apis = sd.query_hostapis()
	idx = int(device.get("hostapi", 0))
	if 0 <= idx < len(apis):
		return str(apis[idx].get("name", ""))
	return ""


def pick_input_device() -> tuple[int, int]:
	"""Prefer a downmixed mapper over the raw 4-channel WASAPI array."""
	devices = sd.query_devices()
	ranked: list[tuple[int, int, int]] = []
	for index, device in enumerate(devices):
		channels = int(device.get("max_input_channels", 0))
		if channels < 1:
			continue
		host = _host_name(device).lower()
		name = str(device.get("name", "")).lower()
		if "stereo mix" in name or "pc speaker" in name:
			continue
		if channels > 2 and "wasapi" in host:
			continue
		score = 0
		if "mme" in host:
			score += 40
		elif "directsound" in host:
			score += 30
		if channels <= 2:
			score += 20
		if "mapper" in name or "primary sound capture" in name:
			score += 15
		if "array" in name:
			score -= 8
		ranked.append((score, index, min(2, channels)))
	if not ranked:
		raise RuntimeError("no recording device found")
	ranked.sort(reverse=True)
	_score, index, channels = ranked[0]
	return index, channels


class MicRing:
	def __init__(self) -> None:
		self._lock = threading.Lock()
		self._chunks: list[np.ndarray] = []
		self._samples = 0
		self._max = int(RATE * MAX_SECONDS)

	def clear(self) -> None:
		with self._lock:
			self._chunks = []
			self._samples = 0

	def push(self, mono: np.ndarray) -> None:
		if mono.size == 0:
			return
		block = np.ascontiguousarray(mono, dtype=np.int16).reshape(-1)
		with self._lock:
			self._chunks.append(block)
			self._samples += int(block.size)
			while self._samples > self._max and self._chunks:
				dropped = self._chunks.pop(0)
				self._samples -= int(dropped.size)

	def dump(self) -> np.ndarray:
		with self._lock:
			if not self._chunks:
				return np.zeros(0, dtype=np.int16)
			return np.concatenate(self._chunks)


class CaptureServer:
	def __init__(self, folder: str) -> None:
		self.folder = folder
		self.ring = MicRing()
		self.stream: sd.InputStream | None = None
		self.device_index = -1
		self.channels = 1
		self.mic_ok = False
		self.camera_module = False
		self.error = ""
		self._last_cmd = ""
		self._detect_camera_module()

	def _detect_camera_module(self) -> None:
		try:
			import cv2  # noqa: F401
			self.camera_module = True
		except Exception:
			self.camera_module = False

	def start_mic(self) -> None:
		self.device_index, self.channels = pick_input_device()
		tried = [self.channels]
		for extra in (1, 2):
			if extra not in tried:
				tried.append(extra)
		last_error: Exception | None = None
		for channels in tried:
			try:
				self._open_stream(channels)
				self.channels = channels
				self.mic_ok = True
				return
			except Exception as exc:
				last_error = exc
		self.mic_ok = False
		self.error = str(last_error or "mic open failed")

	def _open_stream(self, channels: int) -> None:
		if self.stream is not None:
			self.stream.close()
			self.stream = None

		def callback(indata, frames, time_info, status) -> None:  # noqa: ARG001
			if status:
				self.error = str(status)
			if indata.ndim == 1:
				self.ring.push(indata)
			else:
				mixed = np.mean(indata.astype(np.int32), axis=1).astype(np.int16)
				self.ring.push(mixed)

		self.stream = sd.InputStream(
			samplerate=RATE,
			channels=channels,
			dtype="int16",
			device=self.device_index,
			callback=callback,
			blocksize=1024,
		)
		self.stream.start()

	def write_status(self) -> None:
		payload = {
			"ts": time.time(),
			"pid": os.getpid(),
			"mic": self.mic_ok,
			"camera": self.camera_module,
			"device": self.device_index,
			"channels": self.channels,
			"error": self.error,
		}
		path = os.path.join(self.folder, STATUS_NAME)
		tmp = path + ".tmp"
		with open(tmp, "w", encoding="utf-8") as handle:
			json.dump(payload, handle)
		os.replace(tmp, path)

	def ack(self, line: str, ok: bool) -> None:
		path = os.path.join(self.folder, ACK_NAME)
		tmp = path + ".tmp"
		with open(tmp, "w", encoding="utf-8") as handle:
			handle.write(("%s ok\n" if ok else "%s fail\n") % line.strip())
		os.replace(tmp, path)

	def handle(self, line: str) -> None:
		parts = line.split()
		if not parts:
			return
		cmd = parts[0].lower()
		if cmd == "start":
			self.ring.clear()
			self.ack(line, True)
			return
		if cmd == "dump":
			self.ack(line, self._write_wav())
			return
		if cmd == "snap":
			self.ack(line, self._write_pose())
			return
		if cmd == "quit":
			self.ack(line, True)
			self.close()
			sys.exit(0)

	def _write_wav(self) -> bool:
		samples = self.ring.dump()
		if samples.size == 0:
			samples = np.zeros(RATE // 10, dtype=np.int16)
		path = os.path.join(self.folder, WAV_NAME)
		tmp = path + ".tmp"
		with wave.open(tmp, "wb") as handle:
			handle.setnchannels(1)
			handle.setsampwidth(2)
			handle.setframerate(RATE)
			handle.writeframes(samples.tobytes())
		os.replace(tmp, path)
		return True

	def _write_pose(self) -> bool:
		if not self.camera_module:
			self.error = "opencv not installed"
			return False
		import cv2

		cam = cv2.VideoCapture(0, cv2.CAP_DSHOW)
		try:
			ok, frame = cam.read()
		finally:
			cam.release()
		if not ok or frame is None:
			self.error = "webcam frame failed"
			return False
		path = os.path.join(self.folder, POSE_NAME)
		return bool(cv2.imwrite(path, frame))

	def close(self) -> None:
		if self.stream is not None:
			try:
				self.stream.stop()
				self.stream.close()
			except Exception:
				pass
			self.stream = None

	def serve(self) -> None:
		cmd_path = os.path.join(self.folder, CMD_NAME)
		try:
			self.start_mic()
		except Exception as exc:
			self.error = str(exc)
			self.mic_ok = False
		self.write_status()
		try:
			while True:
				self.write_status()
				if os.path.exists(cmd_path):
					try:
						with open(cmd_path, encoding="utf-8") as handle:
							line = handle.read().strip()
					except OSError:
						line = ""
					if line and line != self._last_cmd:
						self._last_cmd = line
						self.handle(line)
				time.sleep(0.04)
		finally:
			self.close()


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--dir", required=True, help="Godot user:// folder")
	args = parser.parse_args()
	folder = os.path.abspath(args.dir)
	os.makedirs(folder, exist_ok=True)
	server = CaptureServer(folder)
	try:
		server.serve()
	except Exception as exc:
		server.error = str(exc)
		server.mic_ok = False
		server.write_status()
		raise


if __name__ == "__main__":
	main()
