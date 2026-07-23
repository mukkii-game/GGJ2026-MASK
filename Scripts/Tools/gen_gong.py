import math
import os
import struct
import wave

path = os.path.join(os.path.dirname(__file__), "..", "..", "Art", "Audio", "Effects", "gong.wav")
path = os.path.normpath(path)
sr = 44100
dur = 2.2
n = int(sr * dur)
partials = [
	(110.0, 1.00, 1.8),
	(155.0, 0.55, 1.5),
	(220.0, 0.35, 1.2),
	(277.0, 0.28, 1.0),
	(330.0, 0.18, 0.9),
	(415.0, 0.12, 0.7),
	(523.0, 0.08, 0.55),
	(660.0, 0.05, 0.4),
	(880.0, 0.03, 0.3),
]
samples = []
for i in range(n):
	t = i / sr
	attack = min(1.0, t / 0.008)
	s = 0.0
	for freq, amp, decay in partials:
		env = math.exp(-decay * t) * attack
		beat = 1.0 + 0.015 * math.sin(2 * math.pi * 1.7 * t)
		s += amp * env * beat * math.sin(2 * math.pi * freq * t)
	if t < 0.02:
		s += 0.35 * (1.0 - t / 0.02) * math.sin(2 * math.pi * 1800 * t) * math.exp(-80 * t)
	samples.append(s)

peak = max(1e-9, max(abs(x) for x in samples))
scale = 0.85 / peak
with wave.open(path, "w") as w:
	w.setnchannels(1)
	w.setsampwidth(2)
	w.setframerate(sr)
	frames = b"".join(
		struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples
	)
	w.writeframes(frames)
print("wrote", path, "bytes", os.path.getsize(path))
