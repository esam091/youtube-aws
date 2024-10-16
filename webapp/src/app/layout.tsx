import '@aws-amplify/ui-react/styles.css';
import './globals.css';
import { Toaster } from "@/components/ui/toaster";
import NavBar from "@/components/NavBar";
import { AmplifyConfig } from "@/components/AmplifyConfig";

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="h-screen flex flex-col">
        <AmplifyConfig />
        <NavBar />
        <main className="flex-grow">
          {children}
        </main>
        <Toaster />
      </body>
    </html>
  );
}
