import { useEffect, useRef, useState, useCallback } from "react";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

const IDLE_WARN_MS = 13 * 60 * 1000;
const IDLE_LOGOUT_MS = 15 * 60 * 1000;

/**
 * Warns staff before automatic client-side logout on long idle (pilot UX).
 * Does not replace server session TTL — pairs with future SSO policies.
 */
export default function SessionIdleGuard({ onLogout }) {
  const [open, setOpen] = useState(false);
  const lastRef = useRef(Date.now());
  const warnRef = useRef(null);
  const logoutRef = useRef(null);

  const bump = useCallback(() => {
    lastRef.current = Date.now();
    setOpen(false);
    if (warnRef.current) clearTimeout(warnRef.current);
    if (logoutRef.current) clearTimeout(logoutRef.current);
    warnRef.current = setTimeout(() => setOpen(true), IDLE_WARN_MS);
    logoutRef.current = setTimeout(() => {
      onLogout?.();
    }, IDLE_LOGOUT_MS);
  }, [onLogout]);

  useEffect(() => {
    const ev = ["mousedown", "keydown", "touchstart", "scroll"];
    const h = () => bump();
    ev.forEach((e) => window.addEventListener(e, h, { passive: true }));
    bump();
    return () => {
      ev.forEach((e) => window.removeEventListener(e, h));
      if (warnRef.current) clearTimeout(warnRef.current);
      if (logoutRef.current) clearTimeout(logoutRef.current);
    };
  }, [bump]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Still there?</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-muted-foreground">
          You have been inactive. For patient privacy this workstation will sign out soon unless you continue.
        </p>
        <DialogFooter>
          <Button type="button" onClick={() => bump()}>
            Continue session
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
