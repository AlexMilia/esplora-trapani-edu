<?php
/* FINTO STRIPE — registra ogni richiesta e risponde con oggetti plausibili. Stato in /tmp/stripe-state.json */
$S = @json_decode(@file_get_contents('/tmp/stripe-state.json'), true) ?: ['log'=>[], 'subs'=>[], 'invoices'=>[], 'seq'=>0];
$m = $_SERVER['REQUEST_METHOD']; $p = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
parse_str(file_get_contents('php://input'), $body); parse_str(parse_url($_SERVER['REQUEST_URI'], PHP_URL_QUERY) ?? '', $q);
$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$S['log'][] = ['m'=>$m,'p'=>$p,'body'=>$body,'q'=>$q,'auth'=>substr($auth,0,14),'idem'=>$_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null];
function out($a,$c=200){ global $S; file_put_contents('/tmp/stripe-state.json', json_encode($S)); http_response_code($c); header('Content-Type: application/json'); echo json_encode($a); exit; }
if ($auth !== 'Bearer sk_test_finto') out(['error'=>['message'=>'Invalid API Key']], 401);
$S['seq']++;
if ($m==='POST' && $p==='/v1/customers') out(['id'=>'cus_'.$S['seq'],'email'=>$body['email']??null,'name'=>$body['name']??null,'metadata'=>['cliente_id'=>$body['metadata']['cliente_id']??null]]);
if ($m==='POST' && $p==='/v1/subscriptions') {
  $id='sub_'.$S['seq']; $inv='in_'.$S['seq'];
  $sub=['id'=>$id,'object'=>'subscription','status'=>'active','customer'=>$body['customer'],'cancel_at_period_end'=>false,'pause_collection'=>null,
        'current_period_start'=>time(),'current_period_end'=>time()+365*86400,'collection_method'=>$body['collection_method']??null,'days_until_due'=>$body['days_until_due']??null,
        'items'=>['data'=>[['price'=>['id'=>$body['items'][0]['price']??null]]]],'metadata'=>$body['metadata']??[]];
  $S['subs'][$id]=$sub; $S['invoices'][$inv]=['id'=>$inv,'status'=>'draft','hosted_invoice_url'=>null,'subscription'=>$id];
  $r=$sub; $r['latest_invoice']=$S['invoices'][$inv]; out($r);
}
if ($m==='POST' && preg_match('#^/v1/invoices/(in_\d+)/finalize$#',$p,$x)) { $S['invoices'][$x[1]]['status']='open'; $S['invoices'][$x[1]]['hosted_invoice_url']='https://invoice.stripe.com/i/'.$x[1]; out($S['invoices'][$x[1]]); }
if ($m==='POST' && preg_match('#^/v1/invoices/(in_\d+)/send$#',$p,$x)) { $S['invoices'][$x[1]]['inviata']=true; out($S['invoices'][$x[1]]); }
if (preg_match('#^/v1/subscriptions/(sub_\d+)$#',$p,$x)) {
  $id=$x[1]; if(!isset($S['subs'][$id])) out(['error'=>['message'=>'No such subscription: '.$id]],404);
  if ($m==='DELETE') { $S['subs'][$id]['status']='canceled'; out($S['subs'][$id]); }
  if ($m==='POST') { $s=&$S['subs'][$id];
    if (array_key_exists('pause_collection',$body)) $s['pause_collection']= ($body['pause_collection']==='' ? null : ['behavior'=>$body['pause_collection']['behavior']??'void']);
    if (isset($body['cancel_at_period_end'])) $s['cancel_at_period_end']=($body['cancel_at_period_end']==='true');
    out($s); }
  $r=$S['subs'][$id]; if(in_array('latest_invoice',$q['expand']??[])) foreach($S['invoices'] as $inv) if($inv['subscription']===$id) $r['latest_invoice']=$inv; out($r);
}
if ($m==='GET' && $p==='/v1/products') out(['data'=>[]]); if ($m==='GET' && $p==='/v1/prices') out(['data'=>[]]);
if ($m==='POST' && $p==='/v1/products') out(['id'=>'prod_'.$S['seq'],'name'=>$body['name']]);
if ($m==='POST' && $p==='/v1/prices') out(['id'=>'price_'.$S['seq'],'unit_amount'=>(int)$body['unit_amount'],'recurring'=>['interval'=>$body['recurring']['interval']],'currency'=>'eur']);
out(['error'=>['message'=>'mock: rotta non gestita '.$m.' '.$p]],400);
