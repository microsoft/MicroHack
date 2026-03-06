import './globals.css'

export const metadata = {
  title: 'AKS Lab - Task Manager',
  description: 'Task Manager application for AKS Lab',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
