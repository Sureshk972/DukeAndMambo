export default function WalkerProfilePage({ params }: { params: { handle: string } }) {
  // SSR'd individual walker profile — primary SEO ranking target.
  return <main className="p-8">Walker profile: {params.handle} — placeholder.</main>;
}
