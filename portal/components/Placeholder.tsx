export default function Placeholder({ title, summary }: { title: string; summary: string }) {
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{title}</h1>
          <p>{summary}</p>
        </div>
      </div>
      <section className="card">
        <p>This page is coming soon.</p>
      </section>
    </>
  );
}
