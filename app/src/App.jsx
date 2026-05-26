import { BrowserRouter, Routes, Route } from "react-router-dom";
import Welcome from "./pages/Welcome.jsx";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Welcome />} />
        {/* Owner-side and provider-side routes get added as pages land. */}
      </Routes>
    </BrowserRouter>
  );
}
