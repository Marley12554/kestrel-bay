"""Extract one level stride from a CMU subject 07 C3D trial for bake-walk.gd."""
import json
import sys
import c3d
import numpy as np
from scipy.signal import find_peaks, savgol_filter


def sample(path):
    with open(path, 'rb') as stream:
        reader = c3d.Reader(stream)
        names = [s.strip().split(':')[-1] for s in reader.point_labels]
        hz = reader.point_rate
        raw = np.stack([p.copy() for _, p, _ in reader.read_frames()])
    times = np.arange(len(raw))
    markers = {}
    for j, name in enumerate(names):
        valid = raw[:, j, 3] >= 0
        points = [np.interp(times, times[valid], raw[valid, j, k]) for k in range(3)]
        markers[name] = savgol_filter(np.array(points).T / 1000, 11, 2, axis=0)
    def mean(*keys):
        return np.mean([markers[k] for k in keys], axis=0)

    hips = mean('LFWT', 'RFWT', 'LBWT', 'RBWT')
    forward = hips[-12] - hips[12]
    forward[2] = 0
    forward /= np.linalg.norm(forward)
    up = np.array([0., 0., 1.])
    left = np.cross(up, forward)
    basis = np.stack([left, up, forward], axis=1)
    foot = (markers['LHEE'] - hips) @ forward
    peaks, _ = find_peaks(foot, distance=hz * .68, prominence=.18)
    # Choose the complete stride nearest the middle of the capture.
    start, end = min(zip(peaks, peaks[1:]), key=lambda p: abs(sum(p) - len(times)))
    duration = (end - start) / hz
    speed = float((hips[end] - hips[start]) @ forward / duration)
    channels = {'pelvis_axis': mean('LFWT', 'LBWT') - mean('RFWT', 'RBWT'),
                'shoulder_axis': markers['LSHO'] - markers['RSHO'],
                'head_axis': mean('LFHD', 'LBHD') - mean('RFHD', 'RBHD'),
                'torso': mean('C7', 'CLAV') - hips}
    for side, sign in [('L', 1), ('R', -1)]:
        hip = hips + sign * left * .095 - up * .07
        knee = markers[side + 'KNE'] - sign * left * .045
        ankle = markers[side + 'ANK'] - sign * left * .035
        elbow = markers[side + 'ELB'] - sign * left * .025
        wrist = mean(side+'WRA', side+'WRB')
        for bone, v in [('thigh', knee-hip), ('calf', ankle-knee),
                        ('foot', markers[side+'TOE']-markers[side+'HEE']),
                        ('upperarm', elbow-markers[side+'SHO']), ('lowerarm', wrist-elbow)]:
            channels[bone+'_'+side.lower()] = v
    frames = []
    stride_times = np.linspace(start, end, round(duration * 30) + 1)
    for t in stride_times:
        frame = {}
        f = (t-start)/(end-start)
        for k, v in channels.items():
            d = np.array([np.interp(t, times, axis) for axis in v.T])
            # Distribute the small displacement between successive heel strikes.
            d -= (v[end] - v[start]) * f
            frame[k] = (d @ basis).round(6).tolist()
        residual = np.array([np.interp(t, times, axis) for axis in hips.T]) - ((1-f)*hips[start]+f*hips[end])
        frame['travel'] = (residual @ basis).round(6).tolist()
        frames.append(frame)
    print(path, 'stride', round(duration, 3), 's, speed', round(speed, 3), 'm/s')
    return {'duration': duration, 'speed': speed, 'frames': frames}


if __name__ == '__main__':
    with open(sys.argv[1], 'w') as out:
        json.dump([sample(path) for path in sys.argv[2:]], out)
