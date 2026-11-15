import wave

with wave.open("song_tester.wav", "rb") as wav:
    assert wav.getnchannels() == 1, "Must be mono"
    assert wav.getsampwidth() == 1, "Must be 8-bit"
    assert wav.getframerate() == 4800, "Must be 4800 Hz"

    samples = wav.readframes(wav.getnframes())

# Convert unsigned WAV samples to signed PCM
samples = bytes(s ^ 0x80 for s in samples)

if len(samples) > 65536 * 4:
    raise ValueError("Song is too long")

print("Number of samples:", len(samples))

# Pad remaining memory with silence
samples = samples.ljust(65536 * 4, b"\x00")

with open("song_tester.mif", "w") as mif:
    mif.write("WIDTH = 32;\n")
    mif.write("DEPTH = 65536;\n")
    mif.write("ADDRESS_RADIX = HEX;\n")
    mif.write("DATA_RADIX = HEX;\n")
    mif.write("CONTENT BEGIN\n")

    for i in range(65536):
        word = samples[i*4:i*4+4].hex()
        mif.write(f"    {i:04X} : {word.upper()};\n")

    mif.write("END;\n")

print("Conversion complete!")