// The page loader (design canvas, "Website · Page loader"): ⠍⠁⠛⠁⠝⠁ fills in amber as the page
// really loads (fonts, the main bundle's scripts and styles, eager images, then React taking
// over), each print letter appears once its cell is complete, with a % and a bar below.
//
// All of it is in the first HTML: markup (set with dangerouslySetInnerHTML, so React never
// diffs it), inline CSS and a small inline script, so it shows before any bundle arrives.
// - No fake delay: at least 0.8 s on screen (no flash), then a fade into the page.
// - "Slow connection. Still loading…" after 8 s.
// - role="progressbar", labelled "Loading Magana"; its value moves one dot at a time, so a
//   screen reader is not counting out loud. Reduced motion: no pop, no fade.
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
.mg-bar i{display:block;height:100%;width:0;border-radius:4px;background:#FFC94A;transition:width .2s linear}
.mg-progress{display:flex;flex-direction:column;align-items:center;gap:20px}
.mg-slow{margin:8px 0 0;font-size:22px;font-weight:700}
.mg-slow:empty{display:none}
@media (prefers-reduced-motion:reduce){#mg-loader,#mg-loader *{transition:none!important}}
`;

// Kept small and plain (ES2017): it runs before anything else on the page.
export const LOADER_JS = `(function(){
var L=document.getElementById("mg-loader");if(!L)return;
var dots=L.querySelectorAll("[data-dot]"),letters=L.querySelectorAll("[data-letter]"),cells=[3,1,4,1,4,1];
var P=L.querySelector("[data-progress]"),pct=L.querySelector("[data-pct]"),bar=L.querySelector("[data-bar]"),slow=L.querySelector("[data-slow]");
var t0=performance.now(),total=0,done=0,shown=0,best=0,domDone=false,ended=false;
var still=matchMedia("(prefers-reduced-motion: reduce)").matches;
function draw(){
 var p=total?done/total:0;if(p<best)p=best;best=p;
 var n=Math.min(14,Math.floor(p*14+1e-9));
 for(var i=shown;i<n;i++)dots[i].setAttribute("data-on","");
 if(n!==shown)P.setAttribute("aria-valuenow",String(Math.round(n/14*100)));
 shown=n;
 for(var c=0,k=0;c<6;c++){k+=cells[c];if(n>=k)letters[c].setAttribute("data-on","");}
 var shownPct=Math.round(p*100);pct.textContent=shownPct;bar.style.width=shownPct+"%";
}
function tick(){done++;draw();if(domDone&&done>=total)finish();}
function add(promise){total++;draw();promise.then(tick,tick);}
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
 domDone=true;draw();if(done>=total)finish();
});
function finish(){
 if(ended)return;ended=true;best=1;draw();
 setTimeout(hide,Math.max(0,800-(performance.now()-t0)));
}
function hide(){
 window.__mgLoader={shownMs:Math.round(performance.now()-t0),slow:slow.textContent!==""};
 if(still){L.hidden=true;return;}
 L.classList.add("mg-out");setTimeout(function(){L.hidden=true;},450);
}
setTimeout(function(){if(!ended)slow.textContent="Slow connection. Still loading\u2026";},8000);
setTimeout(finish,20000);
})();`;
