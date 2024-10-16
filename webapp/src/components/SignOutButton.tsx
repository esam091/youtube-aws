"use client";

import { Button } from "@/components/ui/button";
import { signOut } from "aws-amplify/auth";
import { useRouter } from "next/navigation";

const SignOutButton = () => {
  const router = useRouter()

  return (
    <Button variant="link" className="text-white" onClick={async () => {
      await signOut()
      router.refresh()
    }}>
      Sign Out
    </Button>
  );
};

export default SignOutButton;
