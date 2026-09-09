"use client";
import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { getAdminKey } from "@/lib/api";

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (pathname === "/login") {
      setReady(true);
      return;
    }
    const key = getAdminKey();
    if (!key) {
      router.replace("/login");
    } else {
      setReady(true);
    }
  }, [pathname, router]);

  if (pathname === "/login") return <>{children}</>;
  if (!ready) {
    return (
      <div className="min-h-[60vh] grid place-items-center">
        <div className="text-[13px] text-[#9A8CBF] font-medium">Memeriksa sesi admin...</div>
      </div>
    );
  }
  return <>{children}</>;
}
