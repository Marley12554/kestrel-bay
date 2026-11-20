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
# Preserve the seed position of the original incidental sound effects.
for _ in range(int(.24*rate)):rng.random()
write('reload',.23,lambda t,i: rng.uniform(-.4,.4)*sum(math.exp(-max(0,t-k)*120) if t>=k else 0 for k in [0,.10,.18]))
write('click',.07,lambda t,i: .25*math.sin(math.tau*820*t)*math.exp(-t*90))
write('glass',.6,lambda t,i: rng.uniform(-.5,.5)*math.exp(-t*9)*(.5+.5*math.sin(math.tau*37*t)))
def envelope(t,d):
 return min(1,t*52,(d-t)*34)
write('horn',.42,lambda t,i: envelope(t,.42)*sum(a*math.sin(math.tau*f*t) for f,a in [(355,.28),(445,.23),(710,.12),(890,.08)]))
write('air',.72,lambda t,i:rng.uniform(-.8,.8)*math.exp(-t*5)*min(1,t*70))
write('blast',1.24,lambda t,i: min(1,t*190)*(.59*math.sin(math.tau*(52*t+11*(1-math.exp(-8*t))))*math.exp(-t*4.2)+rng.uniform(-.75,.75)*math.exp(-t*7)))
write('pressure',1.6,lambda t,i:envelope(t,1.6)*(.18*math.sin(math.tau*(610*t+62*t*t))+rng.uniform(-.18,.18))*(.3+.7*t/1.6))

# Render the vehicle and weapon voices offline so a burst has no synthesis cost.
def patrol_call(t, i):
 global phase
 rate_hz = .27 if t < 6 else 1.5
 sweep = .5-.5*math.cos(math.tau*rate_hz*(t if t<6 else t-6))
 freq=555+515*sweep
 phase+=math.tau*freq/rate
 horn=sum(math.sin(phase*n)*a for n,a in [(1,.40),(2,.22),(3,.14),(4,.083),(6,.04)])
 return math.tanh(horn*1.9)*(.85+.1*sweep)*envelope(t,8)
phase=0
write('siren',8,patrol_call)
write('marine-engine',2,lambda t,i: (.25*math.sin(math.tau*43*t)+.16*math.sin(math.tau*86*t)+.12*math.sin(math.tau*129*t))*(.68+.32*math.cos(math.tau*10*t))+.06*rng.uniform(-1,1))
def report(name, pitch, tail):
 low=0.
 delay=[0.]*int(rate*.068)
 def sample(t,i):
  nonlocal low
  noise=rng.uniform(-1,1)
  low=low*.70+noise*.30
  snap=noise*.85*math.exp(-t*99)
  body=.80*math.sin(math.tau*(pitch*t+2.3*(1-math.exp(-t*41))))*math.exp(-t*21)
  dry=math.tanh(2.6*(snap+body+low*1.4*math.exp(-t/tail)))
  echo=delay[i%len(delay)]
  delay[i%len(delay)]=dry+echo*.30
  return (.78*dry+.24*echo)*min(1,t*8500)
 write(name,.65,sample)
for voice,hz,tail in [('shot',96,.073),('shotgun',66,.135),('carbine',128,.057)]:report(voice,hz,tail)
