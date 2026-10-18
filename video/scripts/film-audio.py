# Soundtrack for the ClawdFilm composition: Rhodes-style chords + pad in F, with
# sound effects on every on-screen action. Frame numbers match src/Film.tsx (30fps).
import numpy as np, wave
from scipy.signal import lfilter, butter, sosfilt
sr=44100; FPS=30; total=23.0; n=int(sr*total)
rng=np.random.RandomState(23)
mus=np.zeros((2,n)); fx=np.zeros((2,n)); send=np.zeros((2,n))
def put(bus,t0,sig,g=1.0,pan=0.0,rv=0.0):
    i=int(t0*sr)
    if i<0: sig=sig[-i:]; i=0
    j=min(n,i+len(sig))
    if j<=i: return
    L=np.cos((pan+1)*np.pi/4); R=np.sin((pan+1)*np.pi/4); s=sig[:j-i]*g
    bus[0,i:j]+=s*L; bus[1,i:j]+=s*R
    if rv: send[0,i:j]+=s*L*rv; send[1,i:j]+=s*R*rv
def F(fr): return fr/FPS
def tt(d): return np.arange(int(sr*d))/sr
def lowpass(x,fc,o=2): return sosfilt(butter(o,fc/(sr/2),'low',output='sos'),x,axis=-1)
def highpass(x,fc,o=2): return sosfilt(butter(o,fc/(sr/2),'high',output='sos'),x,axis=-1)
def bandpass(x,lo,hi,o=2): return sosfilt(butter(o,[lo/(sr/2),hi/(sr/2)],'band',output='sos'),x,axis=-1)
def mtof(m): return 440*2**((m-69)/12)

# ---------------- harmony (F major), changes land on story beats
SECT=[(0,[50,57,60,64,65],0.35),      # Dm9 — dark cold open, pad only
      (100,[41,48,57,60,64,67],1),    # Fmaj9 bloom as the desktop is revealed
      (182,[46,53,57,60,64],1),       # Bbmaj9 as he jumps
      (215,[43,50,53,57,62],0.9),     # Gm9 menu bar
      (252,[48,55,57,62,64],1),       # C6/9 timer starts
      (300,[41,48,57,60,64,67],1),    # Fmaj9 files
      (400,[38,45,53,57,60,64],0.6),  # Dm9 sleepy terminal
      (452,[46,53,57,60,62,65],1),    # Bbmaj9 notification
      (490,[43,50,53,58,62],0.9),     # Gm9 games
      (541,[48,55,57,62,64,69],1),    # C6/9 swish
      (606,[41,48,55,57,60,64,69],1.1)]# Fmaj9 home for the outro
ends=[s[0] for s in SECT[1:]]+[int(total*FPS)]
def rhodes(f0,d,vel):
    t=tt(d); mod=np.sin(2*np.pi*f0*t)*(1.6*np.exp(-t*5)+0.25)       # 1:1 FM gives the tine bark
    s=np.sin(2*np.pi*f0*t+mod)*np.exp(-t*0.9)
    s+=0.18*np.sin(2*np.pi*f0*14*t)*np.exp(-t*30)                      # tine click
    trem=1+0.12*np.sin(2*np.pi*4.2*t)
    return lowpass(s*trem*np.minimum(1,t/0.003),2600)*vel
def padv(f0,d):
    t=tt(d); ph=2*np.pi*f0*t+rng.rand()*6
    return sum(np.sin(k*ph)/k**1.3 for k in range(1,6))*(1+0.003*np.sin(2*np.pi*0.2*t))
for (st,ch,lvl),en in zip(SECT,ends):
    t0=F(st); d=F(en)-t0+1.6
    t=tt(d); env=np.minimum(1,t/0.9)*np.minimum(1,np.maximum(0,(d-t)/1.2))
    for side,det in ((-0.6,-0.002),(0.6,0.0023)):
        s=sum(padv(mtof(m)*(1+det),d) for m in ch)
        put(mus,t0-0.15,lowpass(s,900)*env,0.016*lvl,side,0.55)
    if st>0:  # rhodes chord, slightly rolled, on every change
        for k,m in enumerate(ch[1:]):
            put(mus,t0+k*0.018,rhodes(mtof(m),min(d,4.5),0.055*lvl),1,(k/len(ch)-0.5)*0.7,0.45)
        put(mus,t0,np.sin(2*np.pi*mtof(ch[0]-12+12)*t)*env*np.exp(-t*0.3),0.03*lvl,0,0)  # soft bass
# glassy arpeggio, thins out while he sleeps, gone in the cold open
step=60/92/2; k=0; t0=F(104)
pat=[0,2,4,1,3,5,2,4]
while t0<total-2:
    fr=t0*FPS; idx=max(i for i,s in enumerate(SECT) if s[0]<=fr); ch=SECT[idx][1]
    dens=0.35 if 400<=fr<452 else 0.8
    if rng.rand()<dens:
        m=ch[pat[k%8]%len(ch)]+12; f0=mtof(m); t=tt(1.4)
        s=(np.sin(2*np.pi*f0*t)+0.25*np.sin(2*np.pi*f0*3.01*t)*np.exp(-t*8))*np.exp(-t*3.5)*np.minimum(1,t/0.004)
        pan=0.5 if k%2 else -0.5; v=0.028+0.012*rng.rand()
        put(mus,t0,s,v,pan,0.6); put(mus,t0+step*3,s,v*0.35,-pan,0.7)
    k+=1; t0+=step
# room tone
air=highpass(lowpass(rng.randn(n),3000),500)
for c in (0,1): mus[c]+=np.roll(air,c*1311)*0.0035*np.minimum(1,np.arange(n)/sr/3)

# ---------------- sfx kit, pitched to F major
SC=[65,67,69,72,74,76,77,79,81,84,86,88,89,91]
def note(i): return mtof(SC[min(i,len(SC)-1)])
def pop(t0,deg=4,g=1,pan=0,d=0.14):
    t=tt(d); f=note(deg); s=np.sin(2*np.pi*(f+f*0.8*np.exp(-t*55))*t)*np.exp(-t*24)*np.minimum(1,t/0.002)
    put(fx,t0,s,0.3*g,pan,0.35)
def blip(t0,f,g=1,pan=0,d=0.05):
    t=tt(d); put(fx,t0,np.sin(2*np.pi*f*t)*np.exp(-t*70)*np.minimum(1,t/0.001),0.12*g,pan,0.5)
def thud(t0,g=1,pan=0):
    t=tt(0.4); s=np.sin(2*np.pi*(75+80*np.exp(-t*30))*t)*np.exp(-t*12)+lowpass(rng.randn(len(t)),800)*np.exp(-t*50)*0.4
    put(fx,t0,s,0.45*g,pan,0.15)
def step_(t0,g=1,pan=0):
    t=tt(0.05); s=bandpass(rng.randn(len(t)),700,2500)*np.exp(-t*120)+np.sin(2*np.pi*190*t)*np.exp(-t*90)*0.5
    put(fx,t0,s,0.13*g,pan,0.1)
def whoosh(t0,d=0.6,g=1,p0=0.6,p1=-0.6,lo=250,hi=4000):
    t=tt(d); x=rng.randn(len(t)); w=np.sin(np.pi*t/d)**2
    a=bandpass(x,lo,lo*3); b=bandpass(x,hi/3,hi); m=t/d; s=(a*(1-m)+b*m*0.7)*w
    h=len(t)//2; put(fx,t0,s[:h],0.5*g,p0,0.4); put(fx,t0+h/sr,s[h:],0.5*g,p1,0.4)
def riser(t0,d,g=1):
    t=tt(d); x=rng.randn(len(t)); m=(t/d)**2
    s=bandpass(x,400,1200)*(1-m)+bandpass(x,2000,7000)*m
    s=s*m*np.minimum(1,(d-t)/0.05)
    put(fx,t0,s,0.35*g,0,0.6)
def boom(t0,g=1):
    t=tt(2.5); s=np.sin(2*np.pi*(52+30*np.exp(-t*8))*t)*np.exp(-t*1.6)
    put(fx,t0,highpass(lowpass(s,220),45),0.3*g,0,0.2)
def bell(t0,deg=7,g=1,pan=0,dur=2.0):
    t=tt(dur); f=note(deg)
    s=sum(a*np.sin(2*np.pi*f*r*t)*np.exp(-t*dc) for r,a,dc in [(1,1,2.4),(2.0,.22,3.8),(3.01,.1,6),(4.16,.05,9)])
    put(fx,t0,s*np.minimum(1,t/0.002),0.15*g,pan,0.7)
def click(t0,g=1,pan=0.4):
    t=tt(0.025); s=bandpass(rng.randn(len(t)),1800,6000)*np.exp(-t*300)+np.sin(2*np.pi*1400*t)*np.exp(-t*250)*0.5
    put(fx,t0,s,0.28*g,pan,0.12)
def tick(t0,g=1,pan=0.5,hi=True):
    t=tt(0.03); f=3200 if hi else 2400
    s=np.sin(2*np.pi*f*t)*np.exp(-t*240)+bandpass(rng.randn(len(t)),3000,7000)*np.exp(-t*400)*0.4
    put(fx,t0,s,0.12*g,pan,0.15)
def key(t0,g=1,pan=-0.3):
    t=tt(0.04); s=bandpass(rng.randn(len(t)),1000,4500)*np.exp(-t*170)+lowpass(rng.randn(len(t)),350)*np.exp(-t*110)*0.5
    put(fx,t0,s,0.17*g,pan,0.1)
def glide(t0,f0,f1,d,g=1,pan=0):
    t=tt(d); f=np.geomspace(f0,f1,len(t)); s=np.sin(2*np.pi*np.cumsum(f)/sr)*np.sin(np.pi*t/d)**0.6
    put(fx,t0,lowpass(s,3000),0.18*g,pan,0.45)
def swish(t0,g=1,pan=0.6):
    t=tt(0.32); s=bandpass(rng.randn(len(t)),2500,9000)*np.sin(np.pi*t/0.32)**2*np.exp(-t*4)
    put(fx,t0,s,0.6*g,pan,0.5)
def zipper(t0,d=0.28,pan=0):
    for i,tc in enumerate(np.linspace(0,d,14)): click(t0+tc,0.35+0.3*(i%2),pan)
def chirp(t0,pan=0): blip(t0,note(9),1.6,pan,0.07); blip(t0+0.08,note(11),1.6,pan,0.07)
def sparkle(t0,g=1,pan=0):
    for k,deg in enumerate([7,9,11,13]): bell(t0+k*0.07,deg,0.5*g,pan+(k-1.5)*0.15,1.4)
def notif(t0,pan=0.6):  # soft two-tone glass ping
    bell(t0,9,1.2,pan,2.4); bell(t0+0.11,13,0.9,pan,2.4)

# ---------------- cues (frames from Film.tsx)
# cold open: drone + pixels converging into Clawd
t=tt(4); put(fx,0,lowpass(np.sin(2*np.pi*mtof(50)*t)+0.5*np.sin(2*np.pi*mtof(45)*t),300)*np.minimum(1,t/1.5)*np.minimum(1,(4-t)/1),0.12,0,0.3)
for i,fr in enumerate(np.sort(6+rng.rand(70)*30+8)):   # pixel landings
    blip(F(fr),note(int(i/70*8))*2*(1+0.01*rng.randn()),0.55,(rng.rand()-0.5)*0.9)
pop(F(43),9,0.9); pop(F(45),11,0.9)             # eyes land
chirp(F(50)); blip(F(60),2600,0.6)              # hello + blink
pop(F(22),3,0.5); pop(F(25),5,0.5)              # caption
riser(F(66),F(100)-F(66)); boom(F(100),0.9); whoosh(F(72),1.2,0.6,0,0,200,3000)
# desktop: wave, walk, bubble, jump into the menu bar
for fr in range(66,96,8): blip(F(fr),note(7+(fr//8)%3),0.6,0)
for fr in range(130,172,4): step_(F(fr),0.9,-0.1+0.4*(fr-130)/42)
pop(F(106),2,0.5,-0.6); pop(F(112),4,0.5,-0.6)
pop(F(138),6,0.7,0.2); [blip(F(fr),note(10),0.35,0.2) for fr in range(140,156,3)]
glide(F(178),note(0)/2,note(0)/3,0.12,1,0.3)   # crouch
glide(F(182),note(2),note(9),0.55,1.1,0.5)     # jump
whoosh(F(184),0.7,0.5,0.2,0.8,600,5000)
click(F(206),1,0.7); bell(F(207),11,0.6,0.7,1.2)
pop(F(174),3,0.5,-0.6)
# menu: click, open, hover, click, timer
click(F(219),1.1,0.6); whoosh(F(221),0.18,0.35,0.6,0.6,1500,6000)
blip(F(246),note(10),0.5,0.5); click(F(251),1.1,0.5); bell(F(253),7,0.8,0.6); bell(F(254),11,0.5,0.6)
for fr in range(256,292,3): tick(F(fr),0.7,0.6,(fr//3)%2==0)
pop(F(224),2,0.5,-0.6); pop(F(228),4,0.5,-0.6)
# hop out of the bar, land, files
glide(F(292),note(9),note(1),0.7,1,0.5); whoosh(F(296),0.8,0.6,0.6,-0.3,300,3000); thud(F(318),1,-0.1)
whoosh(F(300),0.35,0.4,-0.5,-0.5,800,5000)    # window opens
for i in range(6): pop(F(322+i*2),i+1,0.45,-0.2+i*0.08)
for i,L in enumerate([330,344,358]):
    whoosh(F(L),0.5,0.45,-0.6,0,500,6000)
    land=F(L+16)
    if i==0: pop(land,4,1,-0.2); thud(land,0.3,-0.2)
    if i==1: glide(land,note(11),note(2),0.35,1,0); bell(land+0.12,9,0.7,0)
    if i==2: zipper(land,0.28,0.1)
pop(F(318),3,0.5,-0.6); pop(F(322),5,0.5,-0.6)
for fr in (346,360,374): blip(F(fr+2),note(9),0.4,0)
whoosh(F(392),0.3,0.3,0,-0.6,1500,6000)
# terminal + nap + notification
whoosh(F(398),0.35,0.4,-0.5,-0.5,800,5000)
for fr in np.arange(404,409,0.8): key(F(fr),0.6+0.4*rng.rand())
for fr in np.arange(412,428,0.7):
    if rng.rand()<0.85: key(F(fr),0.5+0.5*rng.rand())
key(F(429),1.3)                                  # enter
for fr in range(430,444,3): blip(F(fr),note(6+(fr//3)%3),0.3,-0.3)
pop(F(444),5,0.5,-0.3); pop(F(449),9,0.6,-0.3)
for fr in (405,425,445): glide(F(fr),note(4)/2,note(2)/2,0.5,0.25,-0.1)   # snores
notif(F(452)); chirp(F(460),0); thud(F(458),0.4,0); [thud(F(fr),0.2,0) for fr in (468,476)]
pop(F(406),3,0.5,0.6); pop(F(410),5,0.5,0.6)
# games
whoosh(F(488),0.3,0.3,-0.4,-0.4,1500,6000)
for fr in range(490,506,4): step_(F(fr),0.8,0.1)
pop(F(494),2,0.8,0.6); pop(F(500),4,0.5,-0.6); pop(F(505),6,0.6,0)
whoosh(F(515),0.5,0.5,0,0.6,600,5000)
swish(F(540)); click(F(541),0.4,0.6); sparkle(F(543),1,0.6); pop(F(543),11,0.8,0.6)
thud(F(556),0.6,0.6); thud(F(578),0.3,0.7)
for fr in range(545,585,10): blip(F(fr),note(7+(fr//10)%4),0.4,0)
# iris close + outro
whoosh(F(584),1.0,0.7,0.5,-0.2,200,4000); boom(F(612),0.7)
for i in range(11): pop(F(618+i*1.6),i,0.28,0.3)  # title letters
pop(F(636),5,0.6,0.3); pop(F(646),7,0.8,0.3); pop(F(654),9,0.5,0.3); sparkle(F(648),0.7,0.2)
blip(F(677),2600,0.5,-0.4)

# ---------------- reverb + mix
def comb(x,D,g,damp):
    a=np.zeros(D+1); a[0]=1; a[D]=-g; return lfilter([1],a,lowpass(x,damp,1))
def allpass(x,D,g):
    b=np.zeros(D+1); b[0]=-g; b[D]=1; a=np.zeros(D+1); a[0]=1; a[D]=-g; return lfilter(b,a,x)
def reverb(x,off):
    y=sum(comb(x,D+off,0.86,4500) for D in (1687,1601,1557,1491,1422,1356))
    for D in (225+off//3,556+off//2): y=allpass(y,D,0.5)
    return y/6
send=highpass(send,220,4); pre=int(0.03*sr)
wet=np.vstack([reverb(np.concatenate([np.zeros(pre),send[c]])[:n],o) for c,o in ((0,0),(1,29))])
wet=highpass(wet,180,4)
out=mus+fx+wet*0.6
out=highpass(out,55,4)
t=np.arange(n)/sr; out*=np.minimum(1,t/0.4)*np.minimum(1,(total-t)/2.2)
out=out/np.percentile(np.abs(out),99.97)*0.95   # let the few loudest transients soft-clip
out=np.tanh(out*1.8)/np.tanh(1.8)*0.89
inter=np.empty(2*n); inter[0::2]=out[0]; inter[1::2]=out[1]
with wave.open('public/film-audio.wav','wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr); w.writeframes((inter*32767).astype(np.int16).tobytes())
sec=[20*np.log10(np.sqrt((out[:,int(s*sr):int((s+1)*sr)]**2).mean())+1e-9) for s in range(int(total))]
print('peak at %.2fs'%(np.abs(out).max(0).argmax()/sr)); print('peak %.2f'%np.abs(out).max(), ' '.join(f'{v:.0f}' for v in sec))
mono=out.mean(0); P=np.abs(np.fft.rfft(mono))**2; fr=np.fft.rfftfreq(len(mono),1/sr)
print(' '.join(f'{lo}-{hi}Hz {100*P[(fr>=lo)&(fr<hi)].sum()/P.sum():.0f}%' for lo,hi in [(0,90),(90,300),(300,2000),(2000,20000)]))
