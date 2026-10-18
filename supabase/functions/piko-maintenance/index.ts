// Scheduled server-only cleanup. Never called by the application and never logs
// identity IDs, bearer tokens, prompts or provider responses.
const url=Deno.env.get('SUPABASE_URL')??'';
const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'';
const jobKey=Deno.env.get('PIKO_MAINTENANCE_TOKEN')??'';
const headers={'content-type':'application/json',apikey:serviceKey,Authorization:`Bearer ${serviceKey}`};
Deno.serve(async request=>{
  if(request.method!=='POST' || jobKey.length<32 ||
    request.headers.get('authorization')!==`Bearer ${jobKey}`) return new Response(null,{status:401});
  if(!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url) || !serviceKey) return new Response(null,{status:503});
  const candidates=await fetch(`${url}/rest/v1/rpc/piko_ai_cleanup_candidates`,{
    method:'POST',headers,body:'{}',redirect:'error',signal:AbortSignal.timeout(10000)});
  if(!candidates.ok) return new Response(null,{status:503});
  const rows=await candidates.json();
  if(!Array.isArray(rows)) return new Response(null,{status:503});
  let removed=0,failed=0;
  for(let offset=0;offset<rows.length;offset+=5){
    await Promise.all(rows.slice(offset,offset+5).map(async row=>{
      if(!/^[0-9a-f-]{36}$/.test(row.identity_id)){failed++;return;}
      try {
        const response=await fetch(`${url}/auth/v1/admin/users/${row.identity_id}`,{
          method:'DELETE',headers,redirect:'error',signal:AbortSignal.timeout(3000)});
        if(response.ok || response.status===404) removed++; else failed++;
      }catch{failed++;}
    }));
  }
  return Response.json({removed,failed},{status:failed?503:200,headers:{'cache-control':'no-store'}});
});
