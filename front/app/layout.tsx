export const metadata = {
  title: "Warren Wallet",
  description: "Micro-ahorros bloqueados + DeFi + ENS + Filecoin (Demo)"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
