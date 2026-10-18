import numpy as np, wave
sr=44100; FPS=30; total=18.5; n=int(sr*total)
amb=np.zeros(n); fx=np.zeros(n); rng=np.random.RandomState(7)
STARTS=[0,90,165,240,315,390,465]
def T(i,lf): return (STARTS[i]+lf)/FPS
def put(buf,t0,sig,g=1.0):
    i=int(t0*sr)
    if i<0: sig=sig[-i:]; i=0
    j=min(n,i+len(sig))
    if j>i: buf[i:j]+=sig[:j-i]*g
def tt(d): return np.arange(int(sr*d))/sr
def lp(x,k): return np.convolve(x,np.ones(k)/k,'same')
def env(t,a,r): return np.minimum(1,t/a)*np.exp(-t*r)
# ---- ambient pad: slow chords w/ detune, vibrato, gentle swell
chords=[[130.81,196.0,246.94,329.63],[110.0,164.81,261.63,329.63],[87.31,130.81,220.0,329.63],[98.0,146.83,246.94,293.66]]
dur=4.6
for k in range(5):
    t0=k*3.7-0.3
    ch=chords[k%4]; t=tt(dur); sig=np.zeros_like(t)
    for f0 in ch:
        for det in (-0.4,0.0,0.5):
            vib=1+0.002*np.sin(2*np.pi*(0.3+det*0.2)*t)
            sig+=np.sin(2*np.pi*f0*(1+det*0.003)*vib*t)+0.3*np.sin(2*np.pi*f0*2*t)*0.5
    swell=np.sin(np.pi*np.clip(t/dur,0,1))**1.5
    put(amb,t0,sig*swell*0.05)
# sparse pentatonic chimes with echo
pent=[523.25,587.33,659.25,783.99,880.0,1046.5]
for t0 in [1.2,3.6,6.0,8.9,11.5,14.0,16.2]:
    f0=pent[rng.randint(len(pent))]; t=tt(1.6)
    s=(np.sin(2*np.pi*f0*t)+0.3*np.sin(2*np.pi*f0*2.01*t))*env(t,0.005,3.2)*0.06
    for d,g in [(0,1),(0.42,0.45),(0.84,0.2)]: put(amb,t0+d,s,g)
# soft air texture
air=lp(rng.randn(n),60); air=lp(air,40); amb+=air/np.abs(air).max()*0.035*np.minimum(1,np.arange(n)/sr/2)
# ---- sfx
def thud(t0,g=1):
    t=tt(.35); put(fx,t0,np.sin(2*np.pi*(95*np.exp(-t*12)+38)*t)*np.exp(-t*11)*0.9,g)
    put(fx,t0,lp(rng.randn(len(t)),30)*np.exp(-t*60)*0.25,g)
def whoosh(t0,d=.42,g=1):
    t=tt(d); x=rng.randn(len(t)); k=np.linspace(60,6,len(t)).astype(int)
    y=np.array([0.0]*len(t)); sm=np.cumsum(x)  # crude band-pass sweep
    a=lp(x,40)-lp(x,5); a=a/np.abs(a).max()
    put(fx,t0,a*np.sin(np.pi*t/d)**2*0.5,g)
def pop(t0,f0=520,g=1,d=.12):
    t=tt(d); put(fx,t0,np.sin(2*np.pi*(f0+f0*1.2*np.exp(-t*40))*t)*np.exp(-t*30)*0.55,g)
def blip(t0,f0,g=1,d=.09):
    t=tt(d); put(fx,t0,np.sign(np.sin(2*np.pi*f0*t))*0.18*np.exp(-t*25),g)
def bell(t0,f0=1318.5,g=1):
    t=tt(1.4)
    s=sum(a*np.sin(2*np.pi*f0*r*t)*np.exp(-t*d) for r,a,d in [(1,1,3.2),(2.76,.4,5),(5.4,.15,8)])
    put(fx,t0,s*0.25,g)
def tick(t0,g=1): t=tt(.02); put(fx,t0,np.sin(2*np.pi*2400*t)*np.exp(-t*220)*0.3,g)
def click(t0,g=1): t=tt(.012); put(fx,t0,rng.randn(len(t))*np.exp(-t*400)*0.35,g)
def boing(t0,d=.5):
    t=tt(d); f=300+700*np.sin(np.pi*np.clip(t/d,0,1)); ph=2*np.pi*np.cumsum(f)/sr
    put(fx,t0,np.sin(ph)*np.exp(-t*4)*0.4)
def zip_(t0):
    t=tt(.3); f=np.linspace(2200,300,len(t)); put(fx,t0,np.sin(2*np.pi*np.cumsum(f)/sr)*np.exp(-t*9)*0.3)
def sparkle(t0,g=1):
    for k,f0 in enumerate([1046.5,1318.5,1568,2093]): pop(t0+k*0.07,f0/2,g*.6,.15); bell(t0+k*0.07,f0,g*.35)
# wipes
for b in STARTS[1:]: whoosh(b/FPS-7/FPS,.5,0.9)
# S1: fall + thud + word pops + chirp
whoosh(T(0,2),.3,.5); thud(T(0,16)); pop(T(0,2),700,.8); pop(T(0,6),480,1); pop(T(0,24),600,.7)
blip(T(0,31),880); blip(T(0,34),1175)
# S2: jump, land in bar, bubble
for i,l in enumerate([0,4,8]): pop(T(1,l),500+i*60,.8)
boing(T(1,18),.7); pop(T(1,40),1200,.9); pop(T(1,46),640,1); blip(T(1,48),1320)
# S3: headline, ticks, bell, badge
pop(T(2,0),420,.8); pop(T(2,4),520,.8)
for l in range(6,46,2): tick(T(2,l),0.35+0.5*(l-6)/40)
bell(T(2,46)); pop(T(2,46),700,.9); blip(T(2,50),1568)
# S4: chips pop, file drop, shrink
for i in range(6): pop(T(3,6+i*3),480+i*45,.55,.09)
whoosh(T(3,8),.5,.6); thud(T(3,30),.55); zip_(T(3,31)); bell(T(3,36),1568,.8); bell(T(3,40),2093,.5)
# S5: typing, window pop, ding
pop(T(4,4),460,.8)
for l in np.arange(12,42,0.7): 
    if rng.rand()<0.8: click(T(4,l),0.5+0.5*rng.rand())
bell(T(4,36),1046.5); bell(T(4,40),1568,.9); pop(T(4,36),800,.7)
# S6: bounces
for l in range(0,75,20): thud(T(5,l),.45)
pop(T(5,0),600,.7); pop(T(5,4),700,.7)
for l in range(10,75,20): blip(T(5,l),700+ (l%40)*8,.4)
# S7: sparkle + pops
sparkle(T(6,2)); pop(T(6,6),520,.8); pop(T(6,18),620,.7); pop(T(6,30),760,.8); sparkle(T(6,34),.6)
# ---- mix
amb=amb/np.abs(amb).max()*0.55; fx=fx/max(np.abs(fx).max(),1e-6)*0.75
out=amb+fx
t=np.arange(n)/sr
out*=np.minimum(1,t/0.6)*np.minimum(1,(total-t)/1.5)
out=np.tanh(out*1.1)*0.9
with wave.open('public/ambient-sfx.wav','wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes((out*32767).astype(np.int16).tobytes())
print('ok',np.abs(out).max())
