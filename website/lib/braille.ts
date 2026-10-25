// Grade 1 (uncontracted) Braille for the letters a–z. Dots are numbered 1–3 down the left
// column and 4–6 down the right.
export const LETTER_DOTS: Record<string, number[]> = {
  a: [1], b: [1, 2], c: [1, 4], d: [1, 4, 5], e: [1, 5], f: [1, 2, 4], g: [1, 2, 4, 5], h: [1, 2, 5],
  i: [2, 4], j: [2, 4, 5], k: [1, 3], l: [1, 2, 3], m: [1, 3, 4], n: [1, 3, 4, 5], o: [1, 3, 5],
  p: [1, 2, 3, 4], q: [1, 2, 3, 4, 5], r: [1, 2, 3, 5], s: [2, 3, 4], t: [2, 3, 4, 5], u: [1, 3, 6],
  v: [1, 2, 3, 6], w: [2, 4, 5, 6], x: [1, 3, 4, 6], y: [1, 3, 4, 5, 6], z: [1, 3, 5, 6],
};

/** Where dot n sits in a cell: column 0 or 1, row 0–2. */
export function dotPosition(n: number): { col: number; row: number } {
  return { col: n <= 3 ? 0 : 1, row: (n - 1) % 3 };
}

/** The Unicode Braille character for a set of dots (U+2800 + one bit per dot). */
export function brailleChar(dots: number[]): string {
  return String.fromCodePoint(0x2800 + dots.reduce((bits, d) => bits | (1 << (d - 1)), 0));
}

export type Cell =
  | { kind: "letter"; char: string; dots: number[] }
  | { kind: "space" }
  | { kind: "unsupported"; char: string };

export function toCells(text: string): Cell[] {
  return [...text].map((ch) => {
    if (ch === " ") return { kind: "space" };
    const dots = LETTER_DOTS[ch.toLowerCase()];
    return dots ? { kind: "letter", char: ch.toLowerCase(), dots } : { kind: "unsupported", char: ch };
  });
}

/** What the live region says: "m: dots 1, 3, 4. a: dot 1." */
export function describe(cells: Cell[]): string {
  return cells
    .map((c) => {
      if (c.kind === "space") return "space";
      if (c.kind === "unsupported") return `${c.char === "" ? "this character" : c.char}: not yet supported`;
      return `${c.char}: ${c.dots.length === 1 ? "dot" : "dots"} ${c.dots.join(", ")}`;
    })
    .join(". ");
}
