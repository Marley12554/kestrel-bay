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
# Integral cycle counts make both the waveform and its slope continuous at wrap.
def ignition(t,i):
 phase=math.tau*58*t+.12*math.sin(math.tau*t/4)
 return .29*math.sin(phase)+.14*math.sin(phase*2+.4)+.085*math.sin(phase*3)+.04*math.sin(phase*5+.28*math.sin(math.tau*t/4))
write('engine',4,ignition)
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
 # Smooth sweep with exactly two wails and an integral number of carrier cycles.
 phase=math.tau*780*t-880*math.sin(math.tau*t/4)
 return .37*math.sin(phase)+.14*math.sin(2*phase+.3)+.055*math.sin(3*phase)
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

filtered=0.
def impact(t,i):
 global filtered
 noise=rng.uniform(-1.,1.)
 filtered=.72*filtered+.28*noise
 body=.46*math.sin(math.tau*(48*t+1.4*(1-math.exp(-34*t))))*math.exp(-12*t)
 crumple=filtered*(math.exp(-t*12)+.55*math.exp(-abs(t-.074)*35))
 ring=.13*math.sin(math.tau*491*t)*math.exp(-19*t)
 return (body+crumple+ring)*min(1,t*700)*min(1,(.64-t)*100)
write('crash',.64,impact)

def fist_voice(name, contact):
 filtered=0.
 def sample(t,i):
  nonlocal filtered
  filtered=.76*filtered+.24*rng.uniform(-1.,1.)
  if contact:
   return min(1,t*430)*math.exp(-t*26)*(.68*math.sin(math.tau*(72*t+.9*(1-math.exp(-45*t))))+.46*filtered)
  return filtered*math.sin(math.pi*t/.16)**2
 write(name,.25 if contact else .16,sample)
fist_voice('swing',False)
fist_voice('thud',True)
