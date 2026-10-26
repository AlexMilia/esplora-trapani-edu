<?php
/* FINTO SUPABASE — auth, RPC edu_e_admin, edu_clienti (con stato persistente), RPC edu_abbonamento_evento */
$S = @json_decode(@file_get_contents('/tmp/supa-state.json'), true) ?: ['log'=>[], 'cliente'=>['id'=>'11111111-aaaa-bbbb-cccc-000000000001','slug'=>'ic-nuovo','nome'=>'IC Nuovo','contatto_nome'=>'Prof. Verdi','contatto_email'=>'verdi@icnuovo.it','stripe_customer_id'=>null,'stripe_subscription_id'=>null,'abbonamento_stato'=>'nessuno','abbonamento_piano'=>null,'abbonamento_periodo'=>null,'abbonamento_link'=>null,'licenza_stato'=>'attiva']];
$m=$_SERVER['REQUEST_METHOD']; $p=parse_url($_SERVER['REQUEST_URI'],PHP_URL_PATH); $raw=file_get_contents('php://input'); $j=json_decode($raw,true);
$auth=$_SERVER['HTTP_AUTHORIZATION']??''; $apikey=$_SERVER['HTTP_APIKEY']??'';
$S['log'][]=['m'=>$m,'p'=>$p,'body'=>$j,'auth'=>$auth,'apikey'=>$apikey];
function out($a,$c=200){ global $S; file_put_contents('/tmp/supa-state.json',json_encode($S)); http_response_code($c); header('Content-Type: application/json'); echo json_encode($a); exit; }
if ($p==='/auth/v1/user') { if($auth==='Bearer tok-admin') out(['id'=>'u-ale','email'=>'ale@x.it']); if($auth==='Bearer tok-docente') out(['id'=>'u-doc','email'=>'d@x.it']); out(['msg'=>'invalid'],401); }
if ($p==='/rest/v1/rpc/edu_e_admin') out($auth==='Bearer tok-admin');
if ($p==='/rest/v1/edu_clienti') {
  if ($auth!=='Bearer service') out(['message'=>'permission denied'],401);
  if ($m==='GET') { parse_str(parse_url($_SERVER['REQUEST_URI'],PHP_URL_QUERY),$q); $id=str_replace('eq.','',$q['id']??''); out($id===$S['cliente']['id']?[$S['cliente']]:[]); }
  if ($m==='PATCH') { $S['cliente']=array_merge($S['cliente'],$j); out([$S['cliente']]); }
}
if ($p==='/rest/v1/rpc/edu_abbonamento_evento') { if($auth!=='Bearer service') out(['message'=>'permission denied'],401); $e=$j['p_evento']??[]; if(($e['subscription']??'')==='sub_ignota') out(['ok'=>false,'err'=>'cliente non trovato']); out(['ok'=>true,'stato'=>'applicato']); }
out(['message'=>'mock: rotta non gestita '.$p],404);
