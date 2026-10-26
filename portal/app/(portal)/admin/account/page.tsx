import type { Metadata } from "next";
import MyAccount from "@/components/MyAccount";

export const metadata: Metadata = { title: "My account" };

export default function Page() {
  return <MyAccount />;
}
