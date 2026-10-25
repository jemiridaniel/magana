import Link from "next/link";

export default function NotFound() {
  return (
    <div className="page">
      <div className="prose">
        <h1>Page not found</h1>
        <p>There is no page at this address. It may have moved.</p>
        <p><Link href="/" className="btn btn-primary">Go to the Magana home page</Link></p>
      </div>
    </div>
  );
}
