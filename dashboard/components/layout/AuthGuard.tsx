"use client";
import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";

function getKey(): string {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("xy_admin_key") || "";
}

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [checked, setChecked] = useState(false);

  // login page never guarded
  if (pathname === "/login") {
    return <>{children}</>;
  }

  useEffect(() => {
    const k = getKey();
    if (!k) {
      router.replace("/login");
    } else {
      setChecked(true);
    }
  }, [pathname, router]);

  // during SSR or before check, avoid infinite spinner — show children if key exists synchronously
  if (typeof window !== "undefined") {
    const k = getKey();
    if (k) {
      return <>{children}</>;
    }
    // if no key, we are redirecting — show minimal to avoid stuck message
    if (!checked) {
      return (
        <div className="min-h-[60vh] grid place-items-center">
          <div className="flex flex-col items-center gap-3">
            <div className="w-8 h-8 rounded-full border-2 border-[#2D1B5E] border-t-[#7C3AED] animate-spin" />
            <div className="text-[13px] text-[#9A8CBF] font-medium">Mengalihkan ke login...</div>
          </div>
        </div>
      );
    }
  }

  if (!checked) {
    return (
      <div className="min-h-[60vh] grid place-items-center">
        <div className="text-[13px] text-[#9A8CBF] font-medium">Memeriksa sesi admin...</div>
      </div>
    );
  }

  return <>{children}</>;
}
