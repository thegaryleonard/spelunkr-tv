// AUTO-EXTRACTED from spelunkr.tv bundle — schedule engine (pure functions).
function Wr(e){let t=e|0;return function(){t=t+1831565813|0;let n=Math.imul(t^t>>>15,1|t);return n^=n+Math.imul(n^n>>>7,61|n),((n^n>>>14)>>>0)/4294967296}}
function Fn(e){let t=0;for(let n=0;n<e.length;n++)t=(t<<5)-t+e.charCodeAt(n)|0;return t}
let Zg=[3,6];
let Lc=20*6e4;
let xu=336*36e5;
let Lt=1e6;
let ui=2e4;
let _f=24*36e5;
let Qg=36e5;
let Wi=e=>{const t=parseInt(e==null?void 0:e.year,10);return Number.isFinite(t)?t:null};
let e0=e=>Math.floor(Wr(Fn(`ad-${e.id}`))()*Lt);
function t0(e){const t=e.map(e0),n=new Array(e.length);return e.map((r,s)=>s).sort((r,s)=>t[r]-t[s]||(e[r].id<e[s].id?-1:e[r].id>e[s].id?1:r-s)).forEach((r,s)=>{n[r]=Math.floor(s*Lt/e.length)}),n}
function n0(e,t){return(Number.isInteger(e==null?void 0:e.start)&&e.start>=0&&e.start<1e3?e.start:(Fn(`ads-${t}`)>>>0)%1e3)*(Lt/1e3)}
function r0(e,{block:t=null,gapMs:n=Lc,sliceMs:r=105e3}={}){let s=0,i=0,o=0,c=0;const l=new Map;return e.forEach((u,d)=>{const f=u.duration*1e3;if(s+=f,i+=f,o+=f,t&&d<e.length-1&&o<t.lengthMs){s+=t.cardMs,i+=t.cardMs,o+=t.cardMs;return}o=0;const h=e[(d+1)%e.length];u.offAir!==!0&&(h==null?void 0:h.offAir)!==!0&&i>=n?(c+=1,l.set(Wi(u),(l.get(Wi(u))||0)+1),s+=ui+r,i=ui/2):(s+=ui,i+=ui)}),{cycleMs:s,total:c,byYear:l}}
function s0(e,t,{block:n=null,gapMs:r=Lc,channelId:s="",start:i,decades:o}={}){const c=t0(e),l=e.reduce((g,v)=>g+v.lengthMs,0)/e.length,u=r0(t,{block:n,gapMs:r,sliceMs:l}),d=e.map(Wi),f=new Map,h=Number.isInteger(o)&&o>=1?`d${o}`:null,p=(g,v)=>{const _=`${g}|${v}`;if(f.has(_))return f.get(_);const S=typeof v=="string"?Number(v.slice(1)):null,y=x=>v===1/0||x!=null&&g!=null&&(S!=null?Math.abs(Math.floor(x/10)-Math.floor(g/10))<=S:Math.abs(x-g)<=v),w=e.map((x,I)=>I).filter(x=>e[x].anywhere===!0||y(d[x])).sort((x,I)=>c[x]-c[I]||(e[x].id<e[I].id?-1:e[x].id>e[I].id?1:x-I));let R=0;for(const[x,I]of u.byYear)y(x)&&(R+=I);const $=u.cycleMs>0?R*xu/u.cycleMs:0,P=w.length>0&&w.length>=$,O=P||w.length===0?xu:Math.max(Qg,Math.floor(w.length*u.cycleMs/R)),k={tol:v,list:w,places:w.map(x=>c[x]),roundMs:O,healthy:P};return f.set(_,k),k},m=new Map;return{phases:c,start:n0({start:i},s),rates:u,tiers(g){if(m.has(g))return m.get(g);const v=g==null?[p(null,1/0)]:[...Zg,...h?[h]:[],1/0].map(S=>p(g,S)),_=v.slice(v.findIndex(S=>S.healthy||S.tol===1/0));return m.set(g,_),_}}}
function Nu(e,t,n){const r=(e%t+t)%t;return(Math.floor(r*Lt/t)+n)%Lt}
function i0(e,t){let n=0,r=e.length;for(;n<r;){const s=n+r>>>1;e[s]<t?n=s+1:r=s}return n}
function o0(e,t,n,r,s=r){t.size>=e.phases.length&&t.clear();const i=e.tiers(n).filter(l=>l.list.length),o=l=>(t.add(l),l),c=[];for(const l of i){const u=l.list.length,d=Nu(s,l.roundMs,e.start),f=Nu(r,l.roundMs,e.start),h=r<=s?0:r-s>=l.roundMs?Lt:(f-d+Lt)%Lt,p=Math.floor(Math.min(_f,l.roundMs)*Lt/l.roundMs),m=i0(l.places,d+1);c.push(m);for(let g=0;g<u;g++){const v=(m+g)%u;if(((l.places[v]-d+Lt)%Lt||Lt)>h)break;if(!t.has(l.list[v]))return o(l.list[v])}for(let g=1;g<=u;g++){const v=(m-g+u*2)%u;if((d-l.places[v]+Lt)%Lt>=p)break;if(!t.has(l.list[v]))return o(l.list[v])}}for(let l=0;l<i.length;l++){const u=i[l],d=u.list.length;for(let f=1;f<=d;f++){const h=u.list[(c[l]-f+d*2)%d];if(!t.has(h))return o(h)}}return-1}
export { s0, o0, t0, Wi, r0 };
