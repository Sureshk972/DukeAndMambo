export default function BrowseByZipPage({ params }: { params: { zip: string } }) {
  // SSR'd list of verified providers serving this zip — placeholder.
  return <main className="p-8">Browse walkers near {params.zip} — placeholder.</main>;
}
