﻿:Class JSONServer
    :Field Public AcceptFrom←⍬    ⍝ IP addressed to accept requests from - empty means all
    :Field Public Port←8080       ⍝
    :Field Public BlockSize←10000 ⍝ Conga block size
    :Field Public CodeLocation←#  ⍝ application code location
    :Field Public InitializeFn←'Initialize' ⍝ name of the application "bootstrap" function
    :Field Public ConfigFile←''
    :Field Public Logging←0       ⍝ turn logging on/off
    :Field Public HtmlInterface←1 ⍝ allow the HTML interface
    :Field Public Debug←0
    :Field Public ClassInterface←1 ⍝ allow for the instantiation and use of classes, 0=no, 1=yes but restrict classes/instance names to not contain #, 2=yes but allow # in class/instance names
    :Field Public FlattenOutput←2  ⍝ 0=no, 1=yes, 2=yes with notification
    :Field Public Traverse←0       ⍝ traverse subordinate namespaces to search for classes (applies only if ClassInterface>0)
    :Field Public IncludeFns←''    ⍝ vector of vectors for function names to be included (can use regex or ? and * as wildcards)
    :Field Public ExcludeFns←''    ⍝ vector of vectors for function names to be excluded (can use regex or ? and * as wildcards)

    :Field _includeRegex←''        ⍝ compiled regex from IncludeFns
    :Field _excludeRegex←''        ⍝ compiled regex from ExcludeFns

⍝ Fields related to running a secure server (to be implemented)
    :Field Public Secure←0
⍝    :Field Public RootCertDir
⍝    :Field Public SSLValidation
⍝    :Field Public ServerCertFile
⍝    :Field Public ServerKeyFile

    :Field _configLoaded←0
    :Field _stop←0               ⍝ set to 1 to stop server
    :Field _started←0
    :Field _stopped←1

    ∇ {r}←Log msg;ts
      :Access public overridable
      ts←,'I4,</>,ZI2,</>,ZI2,< @ >,ZI2,<:>,ZI2,<:>,ZI2'⎕FMT 1 6⍴⎕TS
      :If 1=≢⍴msg←⍕msg
      :OrIf 1=⊃⍴msg
          r←ts,' - ',msg
      :Else
          r←ts,∊(⎕UCS 13),msg
      :EndIf
      ⎕←r
    ∇

    ∇ make
      :Access public
      :Implements constructor
    ∇

    ∇ make1 args;port;loc
      :Access public
      :Implements constructor
    ⍝ args[1] port to listen on
    ⍝     [2] charvec function folder or ref to codelocation
      (Port CodeLocation)←2↑args,(≢,args)↓Port CodeLocation
    ∇

    ∇ UpdateRegex arg;t
      :Implements Trigger IncludeFns, ExcludeFns
      t←makeRegEx¨(⊂'')~⍨∪,⊆arg.NewValue
      :If arg.Name≡'IncludeFns'
          _includeRegex←t
      :Else
          _excludeRegex←t
      :EndIf
    ∇

    ∇ r←Run args;msg;rc
      :Access shared public
      :Trap 0
          (rc msg)←(r←⎕NEW ⎕THIS args).Start
      :Else
          (r rc msg)←'' ¯1 ⎕DMX.EM
      :EndTrap
      r←(r(rc msg))
    ∇

    ∇ (rc msg)←Start
      :Access public
     
      :If _started
          CheckRC(rc msg)←¯1 'Server thinks it''s already started'
      :EndIf
     
      :If _stop
          CheckRC(rc msg)←¯1 'Server is in the process of stopping'
      :EndIf
     
      CheckRC(rc msg)←LoadConfiguration
      CheckRC(rc msg)←CheckPort
      CheckRC(rc msg)←LoadConga
      CheckRC(rc msg)←CheckCodeLocation
      CheckRC(rc msg)←StartServer
      Log'JSONServer started on port ',⍕Port
      Log'CodeLocation is ',⍕CodeLocation
      :If HtmlInterface
          Log'Click http',(~Secure)↓'s://localhost:',(⍕Port),' to access web interface'
      :EndIf
    ∇

    ∇ (rc msg)←Stop;ts
      :Access public
      :If _stop
          CheckRC(rc msg)←¯1 'Server is already stopping'
      :EndIf
      :If ~_started
          CheckRC(rc msg)←¯1 'Server is not running'
      :EndIf
      ts←⎕AI[3]
      _stop←1
      Log'Stopping server...'
      :While ~_stopped
          :If 10000<⎕AI[3]-ts
              CheckRC(rc msg)←¯1 'Server seems stuck'
          :EndIf
      :EndWhile
      _started←_stop←0
    ∇

    ∇ r←Running
      :Access public
      r←~_stop
    ∇

    ∇ (rc msg)←CheckPort;p
      (rc msg)←3('Invalid port: ',∊⍕Port)
      ExitIf 0=p←⊃⊃(//)⎕VFI⍕Port
      ExitIf{(⍵>32767)∨(⍵<1)∨⍵≠⌊⍵}p
      (rc msg)←0 ''
    ∇

    ∇ (rc msg)←LoadConfiguration;config;params
      :Access public
      ⍝!!! wip
      (rc msg)←0 ''
      :If ~0∊⍴ConfigFile
          :Trap 0/0
              :If ⎕NEXISTS ConfigFile
                  config←⎕JSON⊃⎕NGET ConfigFile
                  params←{⍵/'_'≠⊃¨⍵}⎕NL ¯2.2
                  ∘∘∘
                  config.⎕NL ¯2
              :Else
                  →0⊣(rc msg)←6('Configuation file "',ConfigFile,'" not found')
              :EndIf
              _configLoaded←1
          :EndTrap
      :EndIf
    ∇

    ∇ (rc msg)←LoadConga;dyalog
      (rc msg)←0 ''
     
      :If 0=#.⎕NC'Conga'
          dyalog←{⍵,'/'↓⍨'/\'∊⍨¯1↑⍵}2 ⎕NQ'.' 'GetEnvironment' 'DYALOG'
          :Trap 0
              'Conga'#.⎕CY dyalog,'ws/conga'
          :Else
              (rc msg)←1 'Unable to copy Conga'
              →0
          :EndTrap
      :EndIf
     
      :Trap 999 ⍝ Conga.Init signals 999 on error
          #.DRC←#.Conga.Init'JSONServer'
      :Else
          (rc msg)←2 'Unable to initialize Conga'
          →0
      :EndTrap
    ∇

    ∇ (rc msg)←CheckCodeLocation;root;folder;m;res
      (rc msg)←0 ''
      :If 0∊⍴CodeLocation
          CheckRC(rc msg)←4 'CodeLocation is empty!'
      :EndIf
      :Select ⊃{⎕NC'⍵'}CodeLocation ⍝ need dfn because CodeLocation is a field and will always be nameclass 2
      :Case 9 ⍝ reference, just use it
      :Case 2 ⍝ variable, should be file path
          :If isRelPath CodeLocation
              :If 'CLEAR WS'≡⎕WSID
                  root←⊃1 ⎕NPARTS''
              :Else
                  root←⊃1 ⎕NPARTS ⎕WSID
              :EndIf
          :Else
              root←''
          :EndIf
          folder←∊1 ⎕NPARTS root,CodeLocation
          :Trap 0
              :If 1≠1 ⎕NINFO folder
                  CheckRC(rc msg)←5('CodeLocation "',(∊⍕CodeLocation)'," is not a folder.')
              :EndIf
          :Case 22 ⍝ file name error
              CheckRC(rc msg)←6('CodeLocation "',(∊⍕CodeLocation)'," was not found.')
          :Else    ⍝ anything else
              CheckRC(rc msg)←7((⎕DMX.(EM,' (',Message,') ')),'occured when validating CodeLocation "',(∊⍕CodeLocation),'"')
          :EndTrap
          CodeLocation←⍎'CodeLocation'#.⎕NS''
          (rc msg)←CodeLocation LoadFromFolder Folder←folder
      :Else
          CheckRC(rc msg)←5 'CodeLocation is not valid, it should be either a namespace/class reference or a file path'
      :EndSelect
     
      :If ~0∊⍴InitializeFn  ⍝ initialization function specified?
          :If 3=CodeLocation.⎕NC InitializeFn ⍝ does it exist?
              :If 1 0 0≡⊃CodeLocation.⎕AT InitializeFn ⍝ result-returning niladic?
                  res←,⊆CodeLocation⍎InitializeFn        ⍝ run it
                  CheckRC(rc msg)←2↑res,(⍴res)↓¯1('"',(⍕CodeLocation),'.',InitializeFn,'" did not return a 0 return code')
              :Else
                  CheckRC(rc msg)←8('"',(⍕CodeLocation),'.',InitializeFn,'" is not a niladic result-returning function')
              :EndIf
          :EndIf
      :EndIf
    ∇

    ∇ (rc msg)←StartServer;r
      msg←'Unable to start server'
      :If 98 10048∊⍨rc←1⊃r←#.DRC.Srv'' ''Port'http'BlockSize ⍝ 98=Linux, 10048=Windows
          →0⊣msg←'Server could not start - port ',(⍕Port),' is already in use'
      :ElseIf 0=rc
          (_started _stopped)←1 0
          ServerName←2⊃r
          {}#.DRC.SetProp'.' 'EventMode' 1 ⍝ report Close/Timeout as events
          {}#.DRC.SetProp ServerName'FIFOMode' 1
          {}#.DRC.SetProp ServerName'DecodeBuffers' 1
          Connections←#.⎕NS''
          RunServer
          msg←''
      :EndIf
    ∇

    ∇ RunServer
      {}Server&⍬
    ∇

    ∇ Server arg;wres;rc;obj;evt;data;ref;ip
      :While ~_stop
          wres←#.DRC.Wait ServerName 5000 ⍝ Wait for WaitTimeout before timing out
          ⍝ wres: (return code) (object name) (command) (data)
          (rc obj evt data)←4↑wres
          :Select rc
          :Case 0
              :Select evt
              :Case 'Error'
                  _stop←ServerName≡obj
                  :If 0≠4⊃wres
                      Log'RunServer: DRC.Wait reported error ',(⍕#.Conga.Error 4⊃wres),' on ',(2⊃wres),GetIP obj
                  :EndIf
                  Connections.⎕EX obj
     
              :Case 'Connect'
                  obj Connections.⎕NS''
                  (Connections⍎obj).IP←2⊃2⊃#.DRC.GetProp obj'PeerAddr'
     
              :CaseList 'HTTPHeader' 'HTTPTrailer' 'HTTPChunk' 'HTTPBody'
                  {}(Connections⍎obj){t←⍺ HandleRequest ⍵ ⋄ ⎕EX t/⍕⍺}&wres
     
              :CaseList 'Closed' 'Timeout'
     
              :Else ⍝ unhandled event
                  Log'Unhandled Conga event:'
                  Log⍕wres
              :EndSelect ⍝ evt
     
          :Case 1010 ⍝ Object Not found
             ⍝ Log'Object ''',ServerName,''' has been closed - Web Server shutting down'
              →0
     
          :Else
              Log'Conga wait failed:'
              Log wres
          :EndSelect ⍝ rc
      :EndWhile
      {}#.DRC.Close ServerName
      _stopped←1
    ∇

    ∇ r←ns HandleRequest req;data;evt;obj;rc
      (rc obj evt data)←req
      r←0
      :Hold obj
          :Select evt
          :Case 'HTTPHeader'
              ns.Req←⎕NEW Request data
              :If Logging
                  ⎕←('G⊂9999/99/99 @ 99:99:99⊃'⎕FMT 100⊥6↑⎕TS)data
              :EndIf
          :Case 'HTTPBody'
              ns.Req.ProcessBody data
              :If Logging
                  ⎕←('G⊂9999/99/99 @ 99:99:99⊃'⎕FMT 100⊥6↑⎕TS)data
              :EndIf
          :Case 'HTTPChunk'
              ns.Req.ProcessChunk data
          :Case 'HTTPTrailer'
              ns.Req.ProcessTrailer data
          :EndSelect
     
          :If ns.Req.Complete
              :If ns.Req.Response.Status=200
     
                  :If Debug
                      ∘∘∘
                  :EndIf
     
                  HandleJSONRequest ns
              :EndIf
              r←obj Respond ns.Req.Response
          :EndIf
      :EndHold
    ∇

    ∇ HandleJSONRequest ns;payload;fn;resp
      ExitIf HtmlInterface∧ns.Req.Page≡'/favicon.ico'
      :If 0∊⍴fn←1↓'.'@('/'∘=)ns.Req.Page
          ExitIf('No function specified')ns.Req.Fail 400×~HtmlInterface∧'get'≡ns.Req.Method
          ns.Req.Response.Headers←1 2⍴'Content-Type' 'text/html'
          ns.Req.Response.JSON←HtmlPage
          →0
      :EndIf
     
      :Trap Debug↓0
          payload←{0∊⍴⍵:⍵ ⋄ 0 ⎕JSON ⍵}ns.Req.Body
      :Else
          →0⍴⍨'Could not parse payload as JSON'ns.Req.Fail 400
      :EndTrap
     
      :If ClassInterface
      :AndIf (⊂fn)∊'_Classes' '_Delete' '_Get' '_Instances' '_New' '_Run' '_Serialize' '_Set'
          :Trap Debug↓0
              resp←(⍎fn)payload
          :Else
              ns.Req.Response.JSON←1 ⎕JSON ⎕DMX.(EM Message)
              ExitIf('Error running method "',fn,'"')ns.Req.Fail 500
          :EndTrap
      :Else
     
          ExitIf('Invalid function "',fn,'"')ns.Req.Fail CheckFunctionName fn
          ExitIf('Invalid function "',fn,'"')ns.Req.Fail 404×3≠⌊|nameClass←{0::0 ⋄ CodeLocation.⎕NC⊂⍵}fn
          ExitIf('"',fn,'" is not a monadic result-returning function')ns.Req.Fail 400×(nameClass<0)⍱1 1 0≡⊃CodeLocation.⎕AT fn
     
          :Trap Debug↓0
              resp←(CodeLocation⍎fn)payload
          :Else
              ns.Req.Response.JSON←1 ⎕JSON ⎕DMX.(EM Message)
              ExitIf('Error running method "',fn,'"')ns.Req.Fail 500
          :EndTrap
      :EndIf
      :Trap Debug↓0
          ns.Req.Response.JSON←⎕UCS'UTF-8'⎕UCS 1 ⎕JSON resp
      :Else
          :If FlattenOutput>0
              :Trap 0
                  ns.Req.Response.JSON←⎕UCS'UTF-8'⎕UCS JSON resp
                  :If FlattenOutput=2
                      :If 0=⊃payload has'methodName'
                          fn←payload.methodName
                      :EndIf
                      Log'"',fn,'" returned data of rank > 1'
                  :EndIf
              :Else
                  ExitIf'Could not format payload as JSON'ns.Req.Fail 500
              :EndTrap
          :Else
              ExitIf'Could not format payload as JSON'ns.Req.Fail 500
          :EndIf
      :EndTrap
    ∇

    ∇ r←obj Respond res;status;z
      status←(⊂'HTTP/1.1'),res.((⍕Status)StatusText)
      :If res.Status≠200
          res.Headers←1 2⍴'content-type' 'text/html'
      :EndIf
      :If Logging
          ⎕←('G⊂9999/99/99 @ 99:99:99⊃'⎕FMT 100⊥6↑⎕TS)status res.Headers res.JSON
      :EndIf
      :If 0≠1⊃z←#.DRC.Send obj(status,res.Headers res.JSON)1
          Log'Conga error when sending response',GetIP obj
          Log⍕z
      :EndIf
      r←1
    ∇

    ∇ ip←GetIP objname
      ip←{6::'' ⋄ ' (IP Address ',(⍕(Connections⍎⍵).IP),')'}objname
    ∇

    ∇ r←CheckFunctionName fn
    ⍝ checks the requested function name and returns
    ⍝    0 if the function is allowed
    ⍝  404 (not found) if the list of allowed functions is non-empty and fn is not in the list
    ⍝  403 (forbidden) if fn is in the list of disallowed functions
      :Access public
      r←0
      fn←,⊆fn
      :If ~0∊⍴_includeRegex
          ExitIf r←404×0∊⍴(_includeRegex ⎕S'%')fn
      :EndIf
      :If ~0∊⍴_excludeRegex
          r←403×~0∊⍴(_excludeRegex ⎕S'%')fn
      :EndIf
    ∇

    :Class Request
        :Field Public Instance Complete←0        ⍝ do we have a complete request?
        :Field Public Instance Input←''
        :Field Public Instance Host←''           ⍝ host header field
        :Field Public Instance Headers←0 2⍴⊂''   ⍝ HTTPRequest header fields (plus any supplied from HTTPTrailer event)
        :Field Public Instance Method←''         ⍝ HTTP method (GET, POST, PUT, etc)
        :Field Public Instance Page←''           ⍝ Requested URI
        :Field Public Instance Body←''           ⍝ body of the request
        :Field Public Instance PeerAddr←''       ⍝ client IP address
        :Field Public Instance PeerCert←0 0⍴⊂''  ⍝ client certificate
        :Field Public Instance HTTPVersion←''
        :Field Public Instance Cookies←0 2⍴⊂''
        :Field Public Instance CloseConnection←0
        :Field Public Instance Response

        GetFromTable←{(⍵[;1]⍳⊂lc ,⍺)⊃⍵[;2],⊂''}
        split←{p←(⍺⍷⍵)⍳1 ⋄ ((p-1)↑⍵)(p↓⍵)} ⍝ Split ⍵ on first occurrence of ⍺
        lc←(819⌶)
        begins←{⍺≡(⍴⍺)↑⍵}

        ∇ {r}←{a}Fail w
          :Access public
          r←a{⍺←''
              0≠⍵:⍵⊣Response.(Status StatusText)←⍵('Bad Request',(3×0∊⍴⍺)↓' - ',⍺)
              ⍵}w
        ∇

        ∇ make args;query;origin;length
          :Access public
          :Implements constructor
          (Method Input HTTPVersion Headers)←args
          Headers[;1]←lc Headers[;1]  ⍝ header names are case insensitive
          Method←lc Method
         
          Response←⎕NS''
          Response.(Status StatusText Headers JSON)←200 'OK'(1 2⍴'Content-Type' 'application/json; charset=utf-8')''
         
          Host←'host'GetFromTable Headers
          (Page query)←'?'split Input
          Page←PercentDecode Page
          Complete←('get'≡Method)∨(length←'content-length'GetFromTable Headers)≡,'0' ⍝ we're a GET or 0 content-length
          Complete∨←(0∊⍴length)>∨/'chunked'⍷'transfer-encoding'GetFromTable Headers ⍝ or no length supplied and we're not chunked
          :If Complete
          :AndIf ##.HtmlInterface∧~(⊂Page)∊(,'/')'/favicon.ico'
              →0⍴⍨'(Request method should be POST)'Fail 405×'post'≢Method
              →0⍴⍨'(Bad URI)'Fail 400×'/'≠⊃Page
              →0⍴⍨'(Content-Type should be application/json)'Fail 400×~'application/json'begins lc'content-type'GetFromTable Headers
          :EndIf
          →0⍴⍨'(Cannot accept query parameters)'Fail 400×~0∊⍴query
        ∇


        ∇ ProcessBody args
          :Access public
          Body←args
          Complete←1
        ∇

        ∇ ProcessChunk args
          :Access public
        ⍝ args is [1] chunk content [2] chunk-extension name/value pairs (which we don't expect and won't process)
          Body,←1⊃args
        ∇

        ∇ ProcessTrailer args;inds;mask
          :Access public
          args[;1]←lc args[;1]
          mask←(≢Headers)≥inds←Headers[;1]⍳args[;1]
          Headers[mask/inds;2]←mask/args[;2]
          Headers⍪←(~mask)⌿args
          Complete←1
        ∇

        ∇ r←PercentDecode r;rgx;rgxu;i;j;z;t;m;⎕IO;lens;fill
          :Access public shared
        ⍝ Decode a Percent Encoded string https://en.wikipedia.org/wiki/Percent-encoding
          ⎕IO←0
          ((r='+')/r)←' '
          rgx←'[0-9a-fA-F]'
          rgxu←'%[uU]',(4×⍴rgx)⍴rgx ⍝ 4 characters
          r←(rgxu ⎕R{{⎕UCS 16⊥⍉16|'0123456789ABCDEF0123456789abcdef'⍳⍵}2↓⍵.Match})r
          :If 0≠⍴i←(r='%')/⍳⍴r
          :AndIf 0≠⍴i←(i≤¯2+⍴r)/i
              z←r[j←i∘.+1 2]
              t←'UTF-8'⎕UCS 16⊥⍉16|'0123456789ABCDEF0123456789abcdef'⍳z
              lens←⊃∘⍴¨'UTF-8'∘⎕UCS¨t  ⍝ UTF-8 is variable length encoding
              fill←i[¯1↓+\0,lens]
              r[fill]←t
              m←(⍴r)⍴1 ⋄ m[(,j),i~fill]←0
              r←m/r
          :EndIf
        ∇

        ∇ r←GetHeader name
          :Access Public Instance
          r←(lc name)GetFromTable Headers
        ∇

    :EndClass

    :Section ClassInterface

      has←{ ⍝ checks that arguments exist in a namespace
          9≠⎕NC'⍺':11 'Request parameters are not bundled in an object'
          names←,⊆⍵
          ∨/mask←0=⍺.⎕NC names:6('Request is missing parameter',(1=+/mask)↓'s: ',2↓∊', '∘,¨mask/names)
          0 ''
      }

    ∇ r←initResult w
      r←⎕NS''
      r.(rc message)←0 ''
      :If ~0∊⍴w
          r⍎¨(,⊆w),¨⊂'←'''''
      :EndIf
    ∇

    ∇ r←{type}checkName name;mask;t
      type←⊃{6::⍵ ⋄ type}1 ⍝ 1=instance, 2=class
      r←0 ''
      :Select ⊃ClassInterface
      :Case 0
          r←11 'Class interface has not been enabled'
      :Case 1
          :If '#'∊name
              r←11('Invalid ',(type⊃'instance' 'class'),' location: "',name,'"')
          :EndIf
      :EndSelect
      :If (9.2 9.4[type])≢CodeLocation.⎕NC⊂name
          r←6((type⊃'Instance ' 'Class '),name,' not found')
      :EndIf
      :If ∨/mask←∨/¨(⍷∘name)¨t←'JSONServer.' 'Conga.' 'DRC.'
          r←11('Request cannot refer to ',⊃mask/t)
      :EndIf
    ∇

    ∇ r←_Classes dummy
    ⍝ returns class names
      r←initResult'classes'
      r.classes←'JSONServer' 'HttpCommand'~⍨(¯9.4 traverse)CodeLocation
    ∇

    ∇ r←_Delete instances;mask;t
      r←initResult'deleted' 'notDeleted'
      :If 9=⎕NC'instances'
          CheckRC r.(rc message)←instances has'instanceName'
          instances←instances.instanceName
      :EndIf
      instances←,⊆instances
      :If ∨/mask←0≠⊃¨t←1 checkName¨instances
          r.message←2⊃¨mask/t
          r.rc←{(1+1=≢⍵)⊃999,⍵}∪1⊃¨t ⍝ 999 indicates multiple errors
          →0
      :EndIf
      ⎕EX instances
      r.(deleted notDeleted)←1↓¨(0 1,0=⎕NC instances)⌸'zz' 'zz',instances
    ∇

    ∇ r←_Get ns
    ⍝ ns.instanceName - instance name
    ⍝ ns.what - public field, property, or niladic method name
      r←initResult'value'
     
      CheckRC r.(rc message)←ns has'instanceName' 'what'
      CheckRC r.(rc message)←1 checkName ns.instanceName
     
      :Trap 0
          r.value←⍎'CodeLocation.',ns.instanceName,'.',ns.what
      :Else
          r.(rc message)←⎕DMX.EN(⎕DMX.EM,' while attempting to retrieve ',ns.instanceName,'.',ns.what)
      :EndTrap
    ∇

    ∇ r←_Instances dummy
    ⍝ returns instance names
      r←initResult'instances'
      r.instances←(¯9.2 traverse)CodeLocation
    ∇

    ∇ r←_New ns;arguments;class;none;instance
    ⍝ create an instance of a class
    ⍝ class is a namespace (JSON array) of
    ⍝ className - character vector name of the class to instantiate
    ⍝ [arguments] - optional array of arguments to pass in the constructor
     
      r←initResult'instanceName'
      arguments←none←⊂'none' ⍝ JSON cannot have scalar strings
      :If 9=⎕NC'ns'
          CheckRC r.(rc message)←ns has'className'
          class←ns.className
          arguments←{6::arguments ⋄ ⍵.arguments}ns
      :Else
          class←ns
      :EndIf
     
      CheckRC r.(rc message)←2 checkName class
     
      :Repeat
          instance←class,'_',⎕D[?5⍴10]
      :Until 0=CodeLocation.⎕NC instance
      :Trap 0
          ⍎'CodeLocation.',instance,'←CodeLocation.⎕NEW CodeLocation.',class,(arguments≢none)/' arguments'
          r.instanceName←instance
      :Else
          r.(rc message)←⎕DMX.EN(⎕DMX.EM,' while attempting to create instance of ',class)
      :EndTrap
    ∇

    ∇ r←_Run ns;mask;prefix;exec;rc
      r←initResult''
      mask←0≠ns.⎕NC'instanceName' 'rarg' 'larg'
     
      CheckRC r.(rc message)←ns has'methodName'
      prefix←'CodeLocation.'
      :If mask[1] ⍝ instanceName?
          CheckRC r.(rc message)←1 checkName ns.instanceName
          :If 3≠⌊|(CodeLocation⍎ns.instanceName).⎕NC⊂ns.methodName
              CheckRC r.(rc message)←6('"',ns.methodName,'" is not a public method in ',ns.instanceName)
          :EndIf
          prefix,←ns.instanceName,'.'
      :Else ⍝ not using an instance, validate the name against Include/Exclude filters
          :If 0×rc←CheckFunctionName ns.methodName
              CheckRC r.(rc message)←6('"',ns.methodName,'" is not a valid function to run')
          :EndIf
      :EndIf
      :Select 2⊥mask[2 3]
      :Case 0 ⍝ niladic
          exec←prefix,ns.methodName
      :Case 1 ⍝ error
          CheckRC r.(rc message)←2 'Left argument supplied with no right argument'
      :Case 2 ⍝ monadic
          exec←prefix,ns.methodName,' ns.rarg'
      :Case 3 ⍝ dyadic
          exec←'ns.larg ',prefix,ns.methodName,' ns.rarg'
      :EndSelect
     
      :Trap Debug↓0
          r.result←0(85⌶)exec
      :Case 85
          r.message←'No result returned'
      :Else
          r.(rc message)←⎕DMX.EN(⎕DMX.EM,' while attempting to execute ',prefix,ns.methodName)
      :EndTrap
    ∇

    ∇ r←_Serialize ns;name;ref;value;instanceName
    ⍝ ns.instanceName - instance name to serialize
      r←initResult''
      r.data←⎕NS''
      instanceName←ns
      :If 9=⌊⎕NC'ns'
          CheckRC r.(rc message)←ns has'instanceName'
          instanceName←ns.instanceName
      :EndIf
     
      ref←CodeLocation⍎instanceName
     
      :For name :In ref.⎕NL ¯2
          :Trap 0
              value←ref⍎name
              r.data(name{⍺⍎⍺⍺,'←⍵'})value
          :Else
              r.message,←⊂⎕DMX.EM,' while attempting to retrieve ',instanceName,'.',name
              r.rc⌈←999×r.rc≠0
          :EndTrap
      :EndFor
    ∇

    ∇ r←_Set ns
    ⍝ ns.instanceName - instance name
    ⍝ ns.what - public field or property
    ⍝ ns.value - value to set
      r←initResult''
      CheckRC r.(rc message)←ns has'instanceName' 'what' 'value'
      CheckRC r.(rc message)←1 checkName ns.instanceName
     
      :Select ⌊|(CodeLocation⍎ns.instanceName).⎕NC⊂ns.what
      :Case 2
          :Trap 0
              ⍎'CodeLocation.',ns.instanceName,'.',ns.what,'←ns.value'
              r.message←''
          :Else
              r.(rc message)←⎕DMX.EN(⎕DMX.EM,' while attempting to set ',ns.instanceName,'.',ns.what)
          :EndTrap
      :Case 0
          r.(rc message)←6('"',ns.what,'" is not a field or property in ',ns.instanceName)
      :Else
          r.(rc message)←11('"',ns.what,'" is not a valid field or property name')
      :EndSelect
    ∇


    ∇ r←{start}(type traverse)root;ns
    ⍝ return classes or instances, traversing subordinate namespaces if Traverse is set to 1
      :If 0=⎕NC'start' ⋄ start←'' ⋄ :EndIf
      r←start∘,¨root.⎕NL type
      :If Traverse
          :For ns :In (root.⎕NL ¯9.1)~⊂'Conga'
              r,←(start,ns,'.')(type traverse)root⍎ns
          :EndFor
      :EndIf
    ∇

    :EndSection

    :Section Utilities

    ExitIf←→⍴∘0
    CheckRC←ExitIf(0∘≠⊃)

    ∇ r←flatten w
    ⍝ "flatten" arrays of rank>1
    ⍝ JSON cannot represent arrays of rank>1, so we "flatten" them into vectors of vectors (of vectors...)
      :Access public shared
      r←{(↓⍣(¯1+≢⍴⍵))⍵}w
    ∇

    ∇ r←leaven w
    ⍝ "leaven" JSON vectors of vectors (of vectors...) into higher rank arrays
      :Access public shared
      r←{
          0 1∊⍨≡⍵:⍵
          1=⍴∪≢¨⍵:↑∇¨⍵
          ⍵
      }w
    ∇

    ∇ r←isRelPath w
    ⍝ is path w a relative path?
      r←{{~'/\'∊⍨(⎕IO+2×('Win'≡3↑⊃#.⎕WG'APLVersion')∧':'∊⍵)⊃⍵}3↑⍵}w
    ∇

    lc←(819⌶) ⍝ lower case
    ∇ r←makeRegEx w
    ⍝ convert a simple search using ? and * to regex
      :Access public shared
      r←{0∊⍴⍵:⍵
          ¯1=⎕NC('A'@(∊∘'?*'))r←⍵:('/'=⊣/⍵)↓(¯1×'/'=⊢/⍵)↓⍵   ⍝ already regex? (remove leading/trailing '/'
          r←∊(⊂'\.')@('.'=⊢)r  ⍝ escape any periods
          r←'.'@('?'=⊢)r       ⍝ ? → .
          r←∊(⊂'.*')@('*'=⊢)r  ⍝ * → .*
          '^',r,'$'            ⍝ add start and end of string markers
      }w
    ∇

    ∇ (rc msg)←{root}LoadFromFolder path;type;name;nsName;parts;ns;files;folders;file;folder;ref;r;m
      :Access public shared
    ⍝ Loads an APL "project" folder
      (rc msg)←0 ''
      root←{6::⍵ ⋄ root}#
      files←⊃{(⍵=2)/⍺}/0 1(⎕NINFO⍠1)∊1 ⎕NPARTS path,'/*.dyalog'
      folders←⊃{(⍵=1)/⍺}/0 1(⎕NINFO⍠1)∊1 ⎕NPARTS path,'/*'
      :For file :In files
          ⎕SE.SALT.Load file,' -target=',⍕root
      :EndFor
      :For folder :In folders
          nsName←2⊃1 ⎕NPARTS folder
          ref←0
          :Select root.⎕NC⊂nsName
          :Case 9.1 ⍝ namespace
              ref←root⍎nsName
          :Case 0   ⍝ not defined
              ref←⍎nsName root.⎕NS''
          :Else     ⍝ oops
              msg,←'"',folder,'" cannot be mapped to a valid namespace name',⎕UCS 13
          :EndSelect
          :If ref≢0
              (r m)←ref LoadFromFolder folder
              r←rc⌈r
              msg,←m
          :EndIf
      :EndFor
      msg←¯1↓msg
    ∇
    :EndSection

    :Section JSON

    ∇ r←{debug}JSON array;typ;ic;drop;ns;preserve;quote;qp;eval;t;n
    ⍝ JSONify namespaces/arrays with elements of rank>1
      :Access public shared
      debug←{6::⍵ ⋄ debug}0
      array←{(↓⍣(¯1+≢⍴⍵))⍵}array
      :Trap debug↓0
          :If {(0∊⍴⍴⍵)∧0=≡⍵}array ⍝ simple?
              r←{⎕PP←34 ⋄ (2|⎕DR ⍵)⍲∨/b←'¯'=r←⍕⍵:r ⋄ (b/r)←'-' ⋄ r}array
              →0⍴⍨2|typ←⎕DR array ⍝ numbers?
              :Select ⎕NC⊂'array'
              :CaseList 9.4 9.2
                  ⎕SIGNAL(⎕THIS≡array)/⊂('EN' 11)('Message' 'Array cannot be a class')
              :Case 9.1
                  r←,'{'
                  :For n :In n←array.⎕NL-2 9.1
                      r,←'"',(∊((⊂'\'∘,)@(∊∘'"\'))n),'":' ⍝ name
                      r,←(debug JSON array⍎n),','  ⍝ the value
                  :EndFor
                  r←'}',⍨(-1<⍴r)↓r
              :Else ⋄ r←1⌽'""',escapedChars array
              :EndSelect
          :Else ⍝ is not simple (array)
              r←'['↓⍨ic←isChar array
              :If 0∊⍴array ⋄ →0⊣r←(1+ic)⊃'[]' '""'
              :ElseIf ic ⋄ r,←1⌽'""',escapedChars,array ⍝ strings are displayed as such
              :ElseIf 2=≡array
              :AndIf 0=≢⍴array
              :AndIf isChar⊃array ⋄ →0⊣r←⊃array
              :Else ⋄ r,←1↓∊',',¨debug JSON¨,array
              :EndIf
              r,←ic↓']'
          :EndIf
      :Else ⍝ :Trap 0
          (⎕SIGNAL/)⎕DMX.(EM EN)
      :EndTrap
    ∇

    isChar←{0 2∊⍨10|⎕DR ⍵}
      escapedChars←{
          str←⍵
          ~1∊b←str∊fnrbt←'"\/',⎕UCS 12 10 13 8 9:str
          (b/str)←'\"' '\\' '\/' '\f' '\n' '\r' '\b' '\t'[fnrbt⍳b/str]
          str
      }

    :EndSection

    :Section HTML
    ∇ r←ScriptFollows;n
      :Access public shared
      n←2
      r←{⍵/⍨'⍝'≠⊃¨⍵}{1↓¨⍵/⍨∧\'⍝'=⊃¨⍵}{⍵{((∨\⍵)∧⌽∨\⌽⍵)/⍺}' '≠⍵}¨(1+n⊃⎕LC)↓↓(180⌶)n⊃⎕XSI
      r←2↓∊(⎕UCS 13 10)∘,¨r
    ∇

    ∇ r←HtmlPage
      :Access public shared
      r←ScriptFollows
⍝<!DOCTYPE html>
⍝<html>
⍝<head>
⍝<meta content="text/html; charset=utf-8" http-equiv="Content-Type">
⍝<title>JSONServer</title>
⍝</head>
⍝<body>
⍝<fieldset>
⍝  <legend>Request</legend>
⍝  <form id="myform">
⍝    <table>
⍝      <tr>
⍝        <td><label for="function">Method to Execute:</label></td>
⍝        <td><input id="function" name="function" type="text"></td>
⍝      </tr>
⍝      <tr>
⍝        <td><label for="payload">JSON Data:</label></td>
⍝        <td><textarea id="payload" cols="100" name="payload" rows="10"></textarea></td>
⍝      </tr>
⍝      <tr>
⍝        <td colspan="2"><button onclick="doit()" type="button">Send</button></td>
⍝      </tr>
⍝    </table>
⍝  </form>
⍝</fieldset>
⍝<fieldset>
⍝  <legend>Response</legend>
⍝  <div id="result">
⍝  </div>
⍝</fieldset>
⍝<script>
⍝function doit() {
⍝  document.getElementById("result").innerHTML = "";
⍝  var xhttp = new XMLHttpRequest();
⍝  var fn = document.getElementById("function").value;
⍝  fn = (0 == fn.indexOf('/')) ? fn : '/' + fn;
⍝
⍝  xhttp.open("POST", fn, true);
⍝  xhttp.setRequestHeader("Content-Type", "application/json; charset=utf-8");
⍝
⍝  xhttp.onreadystatechange = function() {
⍝    if (this.readyState == 4){
⍝      if (this.status == 200) {
⍝        var resp = "<pre><code>" + this.responseText + "</code></pre>";
⍝      } else {
⍝        var resp = "<span style='color:red;'>" + this.statusText + "</span>";
⍝      }
⍝      document.getElementById("result").innerHTML = resp;
⍝    }
⍝  }
⍝  xhttp.send(document.getElementById("payload").value);
⍝}
⍝</script>
⍝</body>
⍝</html>
    ∇
    :EndSection

:EndClass
