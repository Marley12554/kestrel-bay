"""Build seamless winter city and vehicle airflow beds for the desktop mix."""
import argparse
import wave
from pathlib import Path

import numpy as np


def build(directory):
    rate = 24000
    seconds = 24
    count = rate * seconds
    rng = np.random.default_rng(33005)
    hz = np.fft.rfftfreq(count, 1 / rate)
    t = np.arange(count) / rate

    def band(low, high):
        spectrum = np.fft.rfft(rng.standard_normal(count))
        spectrum *= (hz / np.maximum(low, hz)) ** 2 / (1 + (hz / high) ** 3)
        spectrum[0] = 0
        x = np.fft.irfft(spectrum, count)
        return x / x.std()

    def write(name, audio):
        pcm = np.round(audio * (26000 / np.abs(audio).max())).astype("<i2")
        with wave.open(str(directory / (name + ".wav")), "wb") as output:
            output.setparams((1 if pcm.ndim == 1 else pcm.shape[1], 2, rate, 0, "NONE", ""))
            output.writeframes(pcm.tobytes())

    # All frequencies/envelopes repeat at the buffer boundary. Keep the city
    # wide and distant, the cabin rush narrow, and the indoor ventilation steady.
    rumble = band(55, 285)
    sweep = .5 + .3 * np.sin(2 * np.pi * t / 12) + .2 * np.sin(2 * np.pi * t / 8)
    body = rumble * (.38 + .22 * sweep) + band(190, 930) * (.13 + .20 * sweep)
    write("winter_city", np.column_stack([body + .14 * band(310, 1500) for _ in range(2)]))
    fan = .5 * band(70, 370) + .13 * band(650, 1700)
    write("reserve_room", fan + .18 * np.sin(2 * np.pi * 120 * t) + .08 * np.sin(2 * np.pi * 240 * t))
    write("winter_airflow", .70 * band(95, 820) + (.21 + .10 * sweep) * band(550, 2850))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    build(parser.parse_args().directory)
