// Supabase Edge Function: place-cod-order
// Deploy with: supabase functions deploy place-cod-order
// Configure secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ALLOWED_ORIGIN
// The service-role key must never be shipped to the browser.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
});

Deno.serve(async (req) => {
  const allowedOrigin = Deno.env.get("ALLOWED_ORIGIN") ?? "";
  const origin = req.headers.get("origin") ?? "";
  const headers = corsHeaders(allowedOrigin && origin === allowedOrigin ? allowedOrigin : allowedOrigin);
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers });
  if (!allowedOrigin || origin !== allowedOrigin) return Response.json({ error: "Origin not allowed" }, { status: 403, headers });

  try {
    const body = await req.json();
    const { customer, address, items } = body ?? {};
    if (!customer || !address || !Array.isArray(items) || items.length < 1 || items.length > 30) {
      return Response.json({ error: "Incomplete checkout details." }, { status: 400, headers });
    }
    const service = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const authHeader = req.headers.get("Authorization");
    let userId: string | null = null;
    if (authHeader?.startsWith("Bearer ")) {
      const token = authHeader.slice(7);
      const { data } = await service.auth.getUser(token);
      if (data.user) userId = data.user.id;
    }
    const cleanItems = items.map((item: { variant_id: string; quantity: number }) => ({
      variant_id: String(item.variant_id),
      quantity: Number(item.quantity),
    }));
    if (cleanItems.some((i) => !/^[0-9a-f-]{36}$/i.test(i.variant_id) || !Number.isInteger(i.quantity))) {
      return Response.json({ error: "Invalid product selection." }, { status: 400, headers });
    }
    const { data, error } = await service.rpc("place_cod_order", {
      p_customer_name: String(customer.name ?? "").trim(),
      p_email: String(customer.email ?? "").trim(),
      p_phone: String(customer.phone ?? "").replace(/\D/g, ""),
      p_shipping_address: address,
      p_items: cleanItems,
      p_user_id: userId,
    });
    if (error) return Response.json({ error: error.message }, { status: 400, headers });
    return Response.json({ success: true, order: data?.[0] }, { status: 200, headers });
  } catch {
    return Response.json({ error: "Unable to place order. Please try again." }, { status: 500, headers });
  }
});
