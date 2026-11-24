"""Bake a seamless buff running bond. Channels store clay tone and two surface slopes."""

from pathlib import Path

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 1024, 512
ACROSS, COURSES = 12, 18
LENGTH, RISE = 0.208, 0.072  # nominal unit including joint, metres


def main():
    rng = np.random.default_rng(1350)
    y, x = np.indices((HEIGHT, WIDTH))
    course = (y + 0.5) * COURSES / HEIGHT
    u = (x + 0.5) * ACROSS / WIDTH + 0.5 * (course.astype(int) % 2)
    # Slightly irregular edges, with the broad face standing proud of the pointing.
    sand = rng.standard_normal(x.shape)
    edge_x = (0.5 - abs(u % 1 - 0.5)) * LENGTH
    edge_y = (0.5 - abs(course % 1 - 0.5)) * RISE
    face = np.clip((np.minimum(edge_x, edge_y) + 0.0007 * sand - 0.0026) / 0.0035, 0, 1)
    face = face * face * (3 - 2 * face)
    batch = rng.normal(0, 0.085, (COURSES, ACROSS))
    neighbours = sum(np.roll(batch, shift, axis) for shift, axis in [(1, 0), (-1, 0), (1, 1), (-1, 1)])
    fired = (0.66 + batch + 0.25 * neighbours)[course.astype(int), u.astype(int) % ACROSS]
    tone = 0.25 + face * (fired - 0.25) + 0.014 * sand
    height = 0.003 * face + 0.00012 * sand
    slopes = []
    for axis, spacing in [(1, ACROSS * LENGTH / WIDTH), (0, COURSES * RISE / HEIGHT)]:
        gradient = (np.roll(height, 1, axis) - np.roll(height, -1, axis)) / (2 * spacing)
        slopes.append(0.5 + 0.5 * gradient)
    packed = np.stack([tone, *slopes], axis=-1)
    target = Path(__file__).resolve().parents[2] / "preview/survey/buff-running-bond.png"
    Image.fromarray(np.rint(np.clip(packed, 0, 1) * 255).astype("uint8")).save(target)


if __name__ == "__main__":
    main()
