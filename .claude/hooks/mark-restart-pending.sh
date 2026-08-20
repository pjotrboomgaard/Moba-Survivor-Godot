#!/bin/bash
# Mark that the game should restart once Claude finishes this turn.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
touch "$DIR/.restart_pending"
