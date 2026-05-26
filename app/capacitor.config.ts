import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.twelvesigma.dukeandmambo",
  appName: "Duke and Mambo",
  webDir: "dist",
  server: {
    androidScheme: "https",
  },
};

export default config;
