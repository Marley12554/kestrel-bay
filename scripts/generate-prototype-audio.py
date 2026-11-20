from pathlib import Path
import math, wave, struct, random
root=Path('godot-prototype/audio');rate=22050;rng=random.Random(78531)
def write(name,duration,fn):
 samples=[]
 for i in range(int(duration*rate)):
  t=i/rate
  value=max(-.98,min(.98,fn(t,i)))
  samples.append(struct.pack('<h',int(value*32767)))
 with wave.open(str(root/(name+'.wav')),'wb') as out:
  out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b''.join(samples))
write('engine',1,lambda t,i: .35*(math.sin(math.tau*65*t)+.38*math.sin(math.tau*130*t)+.16*math.sin(math.tau*195*t))*(.82+.18*math.sin(math.tau*13*t)))
phase=0
def siren(t,i):
 global phase
 f=560+230*(1-math.cos(math.tau*t/4))
 phase+=math.tau*f/rate
 return .23*(math.sin(phase)+.25*math.sin(phase*2)+.10*math.sin(phase*3))
write('siren',4,siren)
write('shot',.24,lambda t,i: (rng.uniform(-1,1)*.7*math.exp(-t*43)+.28*math.sin(math.tau*95*t)*math.exp(-t*24))*min(1,t*3000))
write('reload',.23,lambda t,i: rng.uniform(-.4,.4)*sum(math.exp(-max(0,t-k)*120) if t>=k else 0 for k in [0,.10,.18]))
write('click',.07,lambda t,i: .25*math.sin(math.tau*820*t)*math.exp(-t*90))
write('glass',.6,lambda t,i: rng.uniform(-.5,.5)*math.exp(-t*9)*(.5+.5*math.sin(math.tau*37*t)))
def envelope(t,d):
 return min(1,t*52,(d-t)*34)
write('horn',.42,lambda t,i: envelope(t,.42)*sum(a*math.sin(math.tau*f*t) for f,a in [(355,.28),(445,.23),(710,.12),(890,.08)]))
write('air',.72,lambda t,i:rng.uniform(-.8,.8)*math.exp(-t*5)*min(1,t*70))
write('blast',1.24,lambda t,i: min(1,t*190)*(.59*math.sin(math.tau*(52*t+11*(1-math.exp(-8*t))))*math.exp(-t*4.2)+rng.uniform(-.75,.75)*math.exp(-t*7)))
write('pressure',1.6,lambda t,i:envelope(t,1.6)*(.18*math.sin(math.tau*(610*t+62*t*t))+rng.uniform(-.18,.18))*(.3+.7*t/1.6))
