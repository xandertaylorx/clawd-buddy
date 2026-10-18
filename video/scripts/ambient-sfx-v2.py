import numpy as np, wave
from scipy.signal import lfilter, butter, sosfilt
sr=44100; FPS=30; total=18.5; n=int(sr*total)
rng=np.random.RandomState(11)
STARTS=[0,90,165,240,315,390,465]
def T(i,lf): return (STARTS[i]+lf)/FPS
# stereo buses: dry music, dry fx, reverb send
mus=np.zeros((2,n)); fx=np.zeros((2,n)); send=np.zeros((2,n))
def put(bus,t0,sig,g=1.0,pan=0.0,rv=0.0):
    i=int(t0*sr)
    if i<0: sig=sig[-i:]; i=0
    j=min(n,i+len(sig))
    if j<=i: return
    L=np.cos((pan+1)*np.pi/4); R=np.sin((pan+1)*np.pi/4)
    s=sig[:j-i]*g
    bus[0,i:j]+=s*L; bus[1,i:j]+=s*R
    if rv: send[0,i:j]+=s*L*rv; send[1,i:j]+=s*R*rv
def tt(d): return np.arange(int(sr*d))/sr
def lowpass(x,fc,o=2): return sosfilt(butter(o,fc/(sr/2),'low',output='sos'),x)
def highpass(x,fc,o=2): return sosfilt(butter(o,fc/(sr/2),'high',output='sos'),x)
def bandpass(x,lo,hi,o=2): return sosfilt(butter(o,[lo/(sr/2),hi/(sr/2)],'band',output='sos'),x)
def mtof(m): return 440*2**((m-69)/12)
# ---------- harmony: one chord per scene (D major, dreamy)
CH=[[50,57,61,64,66],[47,54,57,61,62],[43,50,54,57,61],[40,47,50,54,57],[43,50,55,57,62],[45,52,57,59,64],[50,57,62,64,69]]
bounds=[s/FPS for s in STARTS]+[total]
# pad: warm detuned saw-ish stack, low-passed, per-scene crossfade
def pad_voice(f0,d,det):
    t=tt(d); ph=2*np.pi*f0*(1+det)*t+rng.rand()*6
    s=sum(np.sin(k*ph)/k for k in range(1,7))
    return s*(1+0.003*np.sin(2*np.pi*0.25*t))
for i,ch in enumerate(CH):
    t0=bounds[i]-0.35; d=bounds[i+1]-bounds[i]+1.4
    t=tt(d); envl=np.minimum(1,t/0.7)*np.minimum(1,np.maximum(0,(d-t)/0.9))
    for side,det in ((-0.6,-0.0025),(0.6,0.0025)):
        s=np.zeros(len(t))
        for m in ch: s+=pad_voice(mtof(m),d,det*(1+rng.rand()))
        cut=900+500*np.sin(np.pi*np.clip(t/d,0,1))   # filter swell, apply as 2 mixed bands
        s=lowpass(s,700)*0.6+lowpass(s,1600)*0.4*np.sin(np.pi*np.clip(t/d,0,1))
        put(mus,t0,s*envl,0.022,side,0.6)
    # sub bass on root
    sub=np.sin(2*np.pi*mtof(ch[0]-12)*t)*envl
    put(mus,t0,sub,0.045,0,0)
# felt-piano plucks: gentle 8ths at 96 bpm from chord tones, soft velocity, ping-pong
step=60/96/2
def pluck(f0,d=1.6):
    t=tt(d)
    s=np.sin(2*np.pi*f0*t)+0.35*np.sin(2*np.pi*2*f0*t)*np.exp(-t*6)+0.12*np.sin(2*np.pi*3*f0*t)*np.exp(-t*10)
    att=np.minimum(1,t/0.004)
    return lowpass(s*att*np.exp(-t*3.2),3000)
pat=[0,2,1,3,2,4,3,1]
k=0; t0=0.9
while t0<total-1.6:
    sc=max(i for i in range(7) if bounds[i]<=t0+0.01)
    ch=CH[sc]; m=ch[pat[k%8]%len(ch)]+12
    if rng.rand()<0.78:
        v=0.05+0.03*rng.rand()*(1 if k%2==0 else 0.6)
        pan=(-0.45 if k%2 else 0.45)
        sig=pluck(mtof(m)); put(mus,t0,sig,v,pan,0.5)
        put(mus,t0+step*3,sig,v*0.3,-pan,0.6)   # echo
    k+=1; t0+=step
# air
air=highpass(lowpass(rng.randn(n),3500),600)
for c in (0,1): mus[c]+=np.roll(air,c*997)*0.004
# ---------- SFX, pitched to D major
DM=[62,64,66,69,71,74,76,78,81,83,86]
def note(i): return mtof(DM[i%len(DM)]+12*(i//len(DM)))
def pop(t0,deg=4,g=1,pan=0,d=0.14):
    t=tt(d); f=note(deg)
    s=np.sin(2*np.pi*(f+f*0.9*np.exp(-t*55))*t)*np.exp(-t*24)*np.minimum(1,t/0.002)
    put(fx,t0,s,0.32*g,pan,0.35)
def thud(t0,g=1,pan=0):
    t=tt(0.45); s=np.sin(2*np.pi*(mtof(38)*1.0+70*np.exp(-t*30))*t)*np.exp(-t*9)
    s+=lowpass(rng.randn(len(t)),900)*np.exp(-t*45)*0.5
    put(fx,t0,s,0.55*g,pan,0.2)
def whoosh(t0,d=0.55,g=1,pan0=0.8,pan1=-0.8):
    t=tt(d); x=rng.randn(len(t)); w=np.sin(np.pi*t/d)**2
    lo=bandpass(x,300,1200); hi=bandpass(x,1500,5000)
    mix=t/d; s=(lo*(1-mix)+hi*mix*0.6)*w
    half=len(t)//2
    put(fx,t0,s[:half],0.55*g,pan0,0.4); put(fx,t0+half/sr,s[half:],0.55*g,pan1,0.4)
def bell(t0,deg=7,g=1,pan=0):
    t=tt(2.2); f=note(deg)
    s=sum(a*np.sin(2*np.pi*f*r*t)*np.exp(-t*dc) for r,a,dc in [(1,1,2.2),(2.0,.25,3.5),(3.01,.12,6),(4.2,.06,9)])
    put(fx,t0,s*np.minimum(1,t/0.002),0.16*g,pan,0.7)
def tick(t0,g=1,pan=0.35):
    t=tt(0.03); s=bandpass(rng.randn(len(t)),2500,6000)*np.exp(-t*260)
    s+=np.sin(2*np.pi*note(11)*t)*np.exp(-t*160)*0.4
    put(fx,t0,s,0.22*g,pan,0.15)
def key(t0,g=1,pan=0.4):
    t=tt(0.04); s=bandpass(rng.randn(len(t)),1200,4500)*np.exp(-t*180)
    s+=lowpass(rng.randn(len(t)),400)*np.exp(-t*120)*0.6
    put(fx,t0,s,0.2*g,pan,0.12)
def jump(t0,pan=0.4,d=0.6):
    t=tt(d); f=note(2)*(1+1.4*np.sin(np.pi*0.5*np.clip(t/d,0,1)))
    s=np.sin(2*np.pi*np.cumsum(f)/sr)*np.exp(-t*3.5)*np.minimum(1,t/0.01)
    put(fx,t0,lowpass(s,2500),0.22,pan,0.4)
def shrink(t0,pan=0.4):
    t=tt(0.4); f=np.linspace(note(12),note(2),len(t))
    s=np.sin(2*np.pi*np.cumsum(f)/sr)*np.exp(-t*7)
    put(fx,t0,s,0.18,pan,0.4)
def sparkle(t0,g=1,pan=0):
    for k,deg in enumerate([7,9,11,14,16]): bell(t0+k*0.075,deg,0.55*g,pan+(k-2)*0.15); pop(t0+k*0.075,deg,0.35*g,pan)
def chirp(t0,pan):
    pop(t0,9,0.7,pan); pop(t0+0.09,11,0.7,pan)
# wipes (sweep L->R matching the wipe direction: enters right, exits left)
for b in STARTS[1:]: whoosh(b/FPS-7/FPS-0.05,0.55,0.9,0.7,-0.7)
# S1
whoosh(T(0,0),0.5,0.4,0.5,0.5); thud(T(0,16),1,0.45)
pop(T(0,2),2,0.8,-0.4); pop(T(0,6),4,1,-0.4); pop(T(0,24),6,0.6,-0.4); chirp(T(0,31),0.45); bell(T(0,34),11,0.5,0.45)
# S2
for i,l in enumerate([0,4,8]): pop(T(1,l),3+i,0.75,-0.45)
jump(T(1,18),0.4); pop(T(1,40),11,0.8,0.55); bell(T(1,41),9,0.6,0.55); pop(T(1,46),7,0.9,0.3); chirp(T(1,49),0.35)
# S3
pop(T(2,0),2,0.8,-0.45); pop(T(2,4),4,0.8,-0.45)
for l in range(6,46,2): tick(T(2,l),0.4+0.6*(l-6)/40,0.45)
bell(T(2,46),7,1.1,0.45); bell(T(2,46),11,0.6,0.45); pop(T(2,47),9,0.8,-0.5)
# S4
for i in range(6): pop(T(3,6+i*3),2+i,0.5,0.25+0.1*(i%3))
pop(T(3,0),1,0.7,-0.45); pop(T(3,4),3,0.7,-0.45); pop(T(3,8),5,0.7,-0.45)
whoosh(T(3,8),0.7,0.5,0.8,0.2); thud(T(3,30),0.45,0.2); shrink(T(3,31),0.3); bell(T(3,36),9,0.8,0.3); bell(T(3,40),11,0.6,0.4)
# S5
for i,l in enumerate([0,4,8,12]): pop(T(4,l),2+i,0.6,-0.45)
pop(T(4,4),5,0.6,0.4)
for l in np.arange(12,42,0.9):
    if rng.rand()<0.8: key(T(4,l),0.5+0.5*rng.rand(),0.3+0.2*rng.rand())
bell(T(4,36),7,0.9,0.25); bell(T(4,39),11,0.8,0.3); chirp(T(4,44),0.3)
# S6 bounces + dance
for l in range(0,75,20): thud(T(5,l),0.35,0.7)
pop(T(5,0),2,0.7,-0.45); pop(T(5,4),4,0.7,-0.45)
for l in range(5,75,10): pop(T(5,l),[7,9,11,9][(l//10)%4],0.25,0.35)
# S7
sparkle(T(6,2)); pop(T(6,6),4,0.8); pop(T(6,18),6,0.6); pop(T(6,30),7,0.8,0.3); sparkle(T(6,40),0.6,0.2); bell(T(6,60),14,0.5,0)
# ---------- reverb: stereo Schroeder (combs + allpasses), damped
def comb(x,D,g,damp):
    # y[n]=x[n]+g*lp(y[n-D]); approximate damping by low-passing input
    a=np.zeros(D+1); a[0]=1; a[D]=-g
    return lfilter([1],a,lowpass(x,damp,1))
def allpass(x,D,g):
    b=np.zeros(D+1); b[0]=-g; b[D]=1; a=np.zeros(D+1); a[0]=1; a[D]=-g
    return lfilter(b,a,x)
def reverb(x,off):
    y=sum(comb(x,D+off,0.84,5000) for D in (1557,1617,1491,1422,1277,1356))
    for D in (225+off//3,556+off//2): y=allpass(y,D,0.5)
    return y/6
pre=int(0.025*sr)
send=highpass(send,220,4)
wetL=reverb(np.concatenate([np.zeros(pre),send[0]])[:n],0)
wetR=reverb(np.concatenate([np.zeros(pre),send[1]])[:n],23)
wet=highpass(np.vstack([wetL,wetR]),180,4)
out=mus*1.0+fx*1.0+wet*0.55
out=highpass(out,45,4)
t=np.arange(n)/sr
out*=np.minimum(1,t/0.8)*np.minimum(1,(total-t)/2.0)
pk=np.abs(out).max(); out=out/pk*0.95
out=np.tanh(out*1.25)/np.tanh(1.25)*0.89  # gentle glue
rms=np.sqrt((out**2).mean()); print('peak',np.abs(out).max(),'rms dBFS',20*np.log10(rms))
inter=np.empty(2*n); inter[0::2]=out[0]; inter[1::2]=out[1]
with wave.open('public/ambient-sfx-v2.wav','wb') as w:
    w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((inter*32767).astype(np.int16).tobytes())
# per-second loudness profile for sanity
sec=[20*np.log10(np.sqrt((out[:,int(s*sr):int((s+1)*sr)]**2).mean())+1e-9) for s in range(18)]
print(' '.join(f'{v:.0f}' for v in sec))
mono=out.mean(0); F=np.abs(np.fft.rfft(mono))**2; fr=np.fft.rfftfreq(len(mono),1/sr)
for lo,hi in [(0,90),(90,300),(300,2000),(2000,20000)]: print(f'{lo}-{hi}Hz {100*F[(fr>=lo)&(fr<hi)].sum()/F.sum():.1f}%')
