// The page loader (design canvas, "Website · Page loader"): ⠍⠁⠛⠁⠝⠁ fills in amber as the page
// really loads (fonts, the main bundle's scripts and styles, eager images, then React taking
// over), each print letter appears once its cell is complete, with a % and a bar below.
//
// All of it is in the first HTML: markup (set with dangerouslySetInnerHTML, so React never
// diffs it), inline CSS and a small inline script, so it shows before any bundle arrives.
// - Never jumps: the % and the dots move toward the real progress at most 10% per 100 ms, so
//   each dot pops in order and the bar grows.
// - A minimum fill time, so it never flashes: the first visit in a session fills over at least
//   1.6 s, a refresh or later visit over at least 1 s. Then "magana" holds complete for 0.3 s and
//   the loader fades. A slow connection follows the real progress, which is slower than that.
// - "Slow connection. Still loading…" after 8 s.
// - role="progressbar", labelled "Loading Magana"; its value moves one dot at a time, so a
//   screen reader is not counting out loud. Reduced motion: the fill stays, without pop or fade.
// - Without JavaScript it never shows; if something breaks, CSS hides it after 30 s.
// - Scripts marked nomodule are skipped: modern browsers never load them, so they would never finish.
import { LETTER_DOTS, dotPosition } from "@/lib/braille";

const WORD = "magana";
const CELL_W = 120;
const DOT_GAP = 40;
const X0 = 60;

function svg(): string {
  const parts: string[] = [];
  let i = 0;
  [...WORD].forEach((ch, c) => {
    const x = X0 + c * CELL_W;
    for (let d = 1; d <= 6; d++) {
      const { col, row } = dotPosition(d);
      parts.push(`<circle cx="${x + col * DOT_GAP}" cy="${30 + row * DOT_GAP}" r="11" fill="none" stroke="#5A6068" stroke-width="2"/>`);
    }
    for (const d of LETTER_DOTS[ch]) {
      const { col, row } = dotPosition(d);
      parts.push(`<circle data-dot="${i++}" cx="${x + col * DOT_GAP}" cy="${30 + row * DOT_GAP}" r="15" fill="#FFC94A"/>`);
    }
    parts.push(`<text data-letter="${c}" x="${x + DOT_GAP / 2}" y="230" text-anchor="middle" font-size="84" font-weight="700" fill="#FFFFFF">${ch}</text>`);
  });
  const width = X0 * 2 + CELL_W * (WORD.length - 1) + DOT_GAP;
  return `<svg viewBox="0 0 ${width} 260" class="mg-cells" aria-hidden="true" focusable="false">${parts.join("")}</svg>`;
}

export const LOADER_HTML =
  `<div id="mg-loader">` +
  `<div class="mg-progress" data-progress role="progressbar" aria-label="Loading Magana" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">` +
  svg() +
  `<div class="mg-pct"><span data-pct>0</span>%</div>` +
  `<div class="mg-bar"><i data-bar></i></div>` +
  `</div>` +
  // Outside the progressbar (whose children screen readers skip); a live region from the start,
  // so the message is announced once when it is filled in.
  `<p class="mg-slow" data-slow role="status"></p>` +
  `</div>`;

export const LOADER_CSS = `
@font-face{font-family:"Atkinson Hyperlegible";src:url(/fonts/atkinson-hyperlegible-regular.woff2) format("woff2");font-weight:400;font-style:normal;font-display:swap}
@font-face{font-family:"Atkinson Hyperlegible";src:url(/fonts/atkinson-hyperlegible-bold.woff2) format("woff2");font-weight:700;font-style:normal;font-display:swap}
#mg-loader{position:fixed;inset:0;z-index:1000;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;padding:16px;background:#14171A;color:#FFFFFF;font-family:"Atkinson Hyperlegible",system-ui,sans-serif;opacity:1;transition:opacity .4s ease;animation:mg-giveup 0s 30s forwards}
#mg-loader.mg-out{opacity:0;pointer-events:none}
#mg-loader[hidden]{display:none}
@keyframes mg-giveup{to{visibility:hidden;pointer-events:none}}
.mg-cells{width:min(760px,92vw);height:auto;font-family:"Atkinson Hyperlegible",system-ui,sans-serif}
#mg-loader [data-dot]{opacity:0;transform:scale(.2);transform-box:fill-box;transform-origin:center;transition:opacity .12s ease-out,transform .3s cubic-bezier(.3,1.7,.5,1)}
#mg-loader [data-dot][data-on]{opacity:1;transform:scale(1)}
#mg-loader [data-letter]{opacity:0;transform:translateY(14px);transition:opacity .25s ease-out,transform .25s ease-out}
#mg-loader [data-letter][data-on]{opacity:1;transform:none}
.mg-pct{font-size:30px;font-weight:700;font-variant-numeric:tabular-nums}
.mg-bar{width:min(400px,70vw);height:8px;border-radius:4px;background:#3A3F45;overflow:hidden}
.mg-bar i{display:block;height:100%;width:0;border-radius:4px;background:#FFC94A}
.mg-progress{display:flex;flex-direction:column;align-items:center;gap:20px}
.mg-slow{margin:8px 0 0;font-size:22px;font-weight:700}
.mg-slow:empty{display:none}
@media (prefers-reduced-motion:reduce){#mg-loader,#mg-loader *{transition:none!important}}
`;

// Kept small and plain (ES2017): it runs before anything else on the page.
// window.__mgLoader keeps the timeline (when each dot appeared), for the timing checks.
export const LOADER_JS = `(function(){
var L=document.getElementById("mg-loader");if(!L)return;
var dots=L.querySelectorAll("[data-dot]"),letters=L.querySelectorAll("[data-letter]"),cells=[3,1,4,1,4,1];
var P=L.querySelector("[data-progress]"),pct=L.querySelector("[data-pct]"),bar=L.querySelector("[data-bar]"),slow=L.querySelector("[data-slow]");
var t0=performance.now(),total=0,done=0,real=0,shown=0,last=t0,domDone=false,full=0,ended=false;
var still=matchMedia("(prefers-reduced-motion: reduce)").matches;
var first=true;try{first=!sessionStorage.getItem("mg-loaded");sessionStorage.setItem("mg-loaded","1");}catch(e){}
var MIN=first?1600:1000,RATE=0.001,HOLD=300;
var log=window.__mgLoader={firstVisit:first,frames:[],slow:false};
function target(){var p=total?done/total:0;if(domDone&&done>=total)p=1;return Math.max(real,p);}
function frame(now){
 real=target();
 var d=Math.min(real,shown+RATE*(now-last),(now-t0)/MIN);if(d<shown)d=shown;last=now;
 var before=Math.floor(shown*14+1e-9),n=Math.min(14,Math.floor(d*14+1e-9));shown=d;
 for(var i=before;i<n;i++){dots[i].setAttribute("data-on","");log.frames.push([Math.round(now-t0),i+1,Math.round(d*100)]);}
 if(n!==before)P.setAttribute("aria-valuenow",String(Math.round(n/14*100)));
 for(var c=0,k=0;c<6;c++){k+=cells[c];if(n>=k)letters[c].setAttribute("data-on","");}
 var v=Math.round(d*100);pct.textContent=v;bar.style.width=v+"%";
 if(d>=1){if(!full)full=now;if(now-full>=HOLD){hide(now);return;}}
 requestAnimationFrame(frame);
}
function tick(){done++;}
function add(promise){total++;promise.then(tick,tick);}
function settle(el,ev){return new Promise(function(r){el.addEventListener(ev||"load",r);el.addEventListener("error",r);});}
function loaded(url){try{return performance.getEntriesByName(url).length>0;}catch(e){return false;}}
if(document.fonts&&document.fonts.load){
 add(document.fonts.load('400 16px "Atkinson Hyperlegible"'));
 add(document.fonts.load('700 16px "Atkinson Hyperlegible"'));
}
add(new Promise(function(r){window.__mgReady=r;}));
document.addEventListener("DOMContentLoaded",function(){
 var els=document.querySelectorAll('script[src]:not([nomodule]),link[rel="stylesheet"],img:not([loading="lazy"])');
 for(var i=0;i<els.length;i++){
  var el=els[i],url=el.src||el.href;
  if((el.tagName==="IMG"&&el.complete)||(url&&loaded(url))){total++;done++;}
  else add(settle(el));
 }
 domDone=true;
});
function hide(now){
 if(ended)return;ended=true;
 log.shownMs=Math.round(now-t0);log.fullAt=Math.round(full-t0);
 if(still){L.hidden=true;return;}
 L.classList.add("mg-out");setTimeout(function(){L.hidden=true;},450);
}
setTimeout(function(){if(!ended){slow.textContent="Slow connection. Still loading\\u2026";log.slow=true;}},8000);
setTimeout(function(){real=1;domDone=true;total=done;},20000);
requestAnimationFrame(frame);
})();`;
