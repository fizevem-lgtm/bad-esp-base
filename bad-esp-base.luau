-- Sonic AI v13.0 — Heavy Edition
-- Complete rebuild with do..end scope, StatsService fix, Lua 5.1 compat, optimizations
print("=== Sonic AI v13.0 BOOT ===")

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("RunService")
local Http         = game:GetService("HttpService")
local TS           = game:GetService("TweenService")
local MSP          = game:GetService("MarketplaceService")
local StatsService = game:GetService("Stats")
local player       = Players.LocalPlayer
if not player then warn("[SAI] No player") ;return end
print("[SAI] Services OK")

local CFG = {
    modelProvider="gemini", model="gemini-flash-lite-latest",
    apiKeys={gemini="",openai="",anthropic=""}, temp=0.8, maxTokens=8192,
    models={
        gemini={["gemini-flash-lite-latest"]={name="Gemini Flash Lite",free=true},["gemini-2.5-flash-lite"]={name="Gemini 2.5 Flash Lite",free=true},["gemini-2.5-flash"]={name="Gemini 2.5 Flash",free=false},["gemini-2.0-flash"]={name="Gemini 2.0 Flash",free=false}},
        openai={["gpt-4o-mini"]={name="GPT-4o Mini",free=false},["gpt-4o"]={name="GPT-4o",free=false}},
        anthropic={["claude-3-haiku-20240307"]={name="Claude 3 Haiku",free=false},["claude-3-5-sonnet-latest"]={name="Claude 3.5 Sonnet",free=false}},
    },
    aiMemoryEnabled=true, aiMemoryMaxEntries=500, aiMemoryAutoLearn=true,
    keybind="Insert", autoScan=true, autoSpy=true, contextOn=true, contextMax=25000,
    maxDumpScripts=2000, decMaxPerRun=500, saveOnUnload=true, httpTimeout=30,
    dir="SonicAI", testDuration=3, lang="en", ragEnabled=true, ragTopScripts=3, ragTopAnalysis=2,
    kbMaxScripts=2000, kbMaxRemotes=500, kbMaxAnalysis=1000, kbMaxPatterns=500, kbMaxSessions=200,
    autoSaveDecompiled=50, marketplaceEnabled=true, debuggerEnabled=true,
    debuggerMaxBreakpoints=50, debuggerLogMaxLines=1000,
}
local DECO = {safeYield=0.05,slowMultiplier=3,verySlowMult=6,memoryCacheMax=5,uiUpdateEvery=8,maxConversationMsgsRendered=60}

local EF = {Gotham=Enum.Font.Gotham,GothamBold=Enum.Font.GothamBold,GothamMedium=Enum.Font.GothamMedium,Code=Enum.Font.Code}
local EK = Enum.KeyCode

local S = {
    unloaded=false, conns={}, tasks={}, dumped={}, cache={}, remotes={}, convos={}, currentConvoId=nil,
    scanner=nil, scannerReport="", logs={}, busy=false, activeTests={}, snapshot=nil, onLog=nil, renderLogs=nil,
    spyHooked=false, oldNamecall=nil, oldSpyOwner=nil, spyFilter="",
    toggleKey=EK[CFG.keybind] or EK.Insert,
    patterns={detections={},lastRun=0}, currentView=nil, guiVisible=true, customTemplates={}, testCancel={},
    _spyDirty=false, fpsBuffer={}, sessionStartedAt=0, sessionOk=0, sessionPartial=0, sessionFail=0,
    _zombieHTTP=0, _spyLastShown=0, _lastAIWatch=nil, _dumpRendering=false, _decompiledSinceSave=0,
    aiMemory={}, marketplaceScripts={}, marketplaceInstalled={},
    debuggerActive=false, debuggerBreakpoints={}, debuggerWatchVars={}, debuggerLog={}, debuggerCurrentScript=nil,
    startSpy=nil, stopSpy=nil, renderChat=nil, renderDump=nil, renderWorld=nil, renderConvoList=nil,
    renderPatterns=nil, renderSpy=nil, updateDash=nil, updateDecStatus=nil, countCache=nil, scanGame=nil,
    scanScripts=nil, sendMsg=nil, showToast=nil, switchView=nil, log=nil, logTest=nil, openScriptViewer=nil,
    openChatViewer=nil, openDiffViewer=nil, openTemplateEditor=nil, runAsync=nil, detectPatterns=nil,
    saveConvosNow=nil, saveKB=nil, loadKB=nil, kbAddScript=nil, kbAddRemote=nil, kbAddAnalysis=nil,
    kbAddPatterns=nil, kbSaveSession=nil, searchKB=nil, buildRagContext=nil, updateSafety=nil,
    renderSnapshots=nil, renderTemplates=nil, refreshLocale=nil, renderMemory=nil, renderMarketplace=nil,
    renderDebugger=nil, saveConvos=nil,
}
local UI = {gui=nil, views={}, navButtons={}}
local M = {}
local P = {
    bg=Color3.fromRGB(9,9,13), surface1=Color3.fromRGB(15,15,21), surface2=Color3.fromRGB(20,20,28),
    surface3=Color3.fromRGB(26,26,36), surfaceHover=Color3.fromRGB(32,32,44), border=Color3.fromRGB(36,36,48),
    borderLight=Color3.fromRGB(50,50,66), borderFocus=Color3.fromRGB(90,170,255),
    textPrimary=Color3.fromRGB(240,240,250), textSecondary=Color3.fromRGB(150,150,175),
    textMuted=Color3.fromRGB(95,95,118), textInverse=Color3.fromRGB(12,12,18),
    accent=Color3.fromRGB(90,175,255), accentSoft=Color3.fromRGB(65,130,210), accentTint=Color3.fromRGB(22,48,80),
    success=Color3.fromRGB(85,225,145), successTint=Color3.fromRGB(22,65,45),
    warn=Color3.fromRGB(250,195,85), warnTint=Color3.fromRGB(70,55,22),
    danger=Color3.fromRGB(240,95,95), dangerTint=Color3.fromRGB(72,28,28),
    partial=Color3.fromRGB(235,185,105), partialTint=Color3.fromRGB(65,50,22),
    codeBg=Color3.fromRGB(6,6,10), codeHeader=Color3.fromRGB(18,18,26), codeText=Color3.fromRGB(215,215,235),
}

local function hasFS() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" end
local function ensureDir(d) if not hasFS() then return end pcall(function() if isfolder and makefolder and not isfolder(d) then makefolder(d) end end) end
local function safeWrite(p,d) if not hasFS() then return false end return (pcall(writefile,p,d)) end
local function safeRead(p)
    if not hasFS() then return nil end
    local ok,d = pcall(function() if isfile(p) then return readfile(p) end return nil end)
    if ok and type(d)=="string" then return d end
    return nil
end
local function cut(s,n)
    s = tostring(s or "")
    if #s <= n then return s end
    local i = n
    while i > 0 do
        local b = s:byte(i+1)
        if b and b >= 128 and b < 192 then i = i-1 else break end
    end
    return s:sub(1,i)
end
local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function httpReq()
    if type(request)=="function" then return request end
    if type(http_request)=="function" then return http_request end
    if type(syn)=="table" and type(syn.request)=="function" then return syn.request end
    return nil
end
local function clipFn()
    if type(setclipboard)=="function" then return setclipboard end
    if type(toclipboard)=="function" then return toclipboard end
    return nil
end
local function hashString(s)
    local h = 5381
    for i=1,#s do h = ((h*33)+s:byte(i)) % 2147483647 end
    return tostring(h)
end
local function genId(p) return p.."_"..tostring(os.time()).."_"..tostring(math.random(100000,999999)) end
local function fmtTime(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec < 60 then return sec.."s" end
    return math.floor(sec/60).."m "..(sec%60).."s"
end
local function hasFn(name)
    if type(name) ~= "string" or name == "" then return false end
    if getgenv then
        local ok,g = pcall(getgenv)
        if ok and type(g)=="table" and type(g[name])=="function" then return true end
    end
    if type(getfenv)=="function" then
        local ok,env = pcall(getfenv)
        if ok and type(env)=="table" and type(env[name])=="function" then return true end
    end
    if type(loadstring)=="function" then
        local ok,val = pcall(function() local fn = loadstring("return "..name); return fn and fn() end)
        if ok and type(val)=="function" then return true end
    end
    return false
end
local function maskKey(k)
    k = tostring(k or "")
    if k == "" then return "" end
    if #k <= 8 then return "xxxxxxxx" end
    return k:sub(1,4)..string.rep("x",math.min(12,#k-8))..k:sub(-4)
end
local function clearGuiChildren(c)
    if not c then return end
    for _,x in ipairs(c:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
end
local CAP_NAMES = {"hookmetamethod","getnamecallmethod","decompile","getscriptbytecode","request","http_request","setclipboard","loadstring","writefile","getconnections","firesignal","fireclickdetector","fireproximityprompt","getnilinstances","listfiles","gethui"}
local capCache, capCacheAt = nil, 0
local function refreshCaps(force)
    if capCache and not force and (os.clock()-capCacheAt) < 30 then return capCache end
    capCache = {}
    for _,name in ipairs(CAP_NAMES) do capCache[name] = hasFn(name) end
    capCacheAt = os.clock()
    return capCache
end
local function resolveByFullName(fullName)
    if type(fullName) ~= "string" or fullName == "" then return nil end
    local s = fullName
    if s:sub(1,5) == "game." then s = s:sub(6) end
    local cur = game
    for part in string.gmatch(s,"[^.]+") do
        local child = cur:FindFirstChild(part)
        if not child then return nil end
        cur = child
    end
    return cur ~= game and cur or nil
end
local tr, tr_view
local cachedGameName = nil
local getScriptCode = nil

local function getTaskStatus(t)
    if type(t) ~= "thread" then return "dead" end
    local ok,status = pcall(function()
        local ts = task
        if type(ts)=="table" and type(ts.status)=="function" then return ts.status(t) end
        return nil
    end)
    if ok and status then return status end
    local ok2,status2 = pcall(coroutine.status, t)
    if ok2 then return status2 end
    return "unknown"
end
local function isTaskDead(t) return getTaskStatus(t) == "dead" end

local function track(c) S.conns[#S.conns+1] = c; return c end
local function trackTask(t) S.tasks[#S.tasks+1] = t; return t end

local LOG_COLORS = {INFO=Color3.fromRGB(120,180,255),WARN=Color3.fromRGB(250,200,90),ERROR=Color3.fromRGB(240,90,90),SUCCESS=Color3.fromRGB(80,220,120),TEST=Color3.fromRGB(0,220,255)}
S.log = function(level, src, msg)
    local e = {level=level or "INFO", src=src or "core", msg=tostring(msg), ts=os.date("%H:%M:%S")}
    S.logs[#S.logs+1] = e
    while #S.logs > 800 do table.remove(S.logs,1) end
    print(("[SAI][%s][%s] %s"):format(e.level,e.src,e.msg))
    if S.onLog then pcall(S.onLog, e) end
end
S.logTest = function(src,msg) S.log("TEST",src,msg) end

local function httpWithTimeout(opts, timeout)
    timeout = timeout or CFG.httpTimeout
    local reqFn = httpReq()
    if not reqFn then return nil,"no_http_function" end
    local done, result, err = false, nil, nil
    local token = {abandoned=false}
    task.spawn(function()
        local ok,res = pcall(reqFn, opts)
        if token.abandoned then return end
        if ok then result = res else err = tostring(res) end
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock()-t0 < timeout do task.wait(0.1) end
    if not done then
        token.abandoned = true
        S._zombieHTTP = (S._zombieHTTP or 0) + 1
        task.delay(90, function() if S._zombieHTTP and S._zombieHTTP > 0 then S._zombieHTTP = S._zombieHTTP - 1 end end)
        return nil, "timeout_"..tostring(timeout).."s"
    end
    if err then return nil,err end
    return result, nil
end

do
    local raw = safeRead(CFG.dir.."/config.json")
    if raw then
        local ok,data = pcall(Http.JSONDecode, Http, raw)
        if ok and type(data)=="table" then
            for k,v in pairs(data) do
                if k == "apiKeys" and type(v)=="table" then
                    for pk,pv in pairs(v) do CFG.apiKeys[pk]=pv end
                elseif CFG[k] ~= nil and type(v)==type(CFG[k]) then
                    CFG[k] = v
                end
            end
        end
    end
end
local function saveConfig()
    if not hasFS() then return false end
    ensureDir(CFG.dir)
    return safeWrite(CFG.dir.."/config.json", Http:JSONEncode(CFG))
end

local guiParent
do
    if type(gethui)=="function" then
        local ok,h = pcall(gethui)
        if ok and typeof(h)=="Instance" then guiParent = h end
    end
    if not guiParent then
        local ok,cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then
            local can = pcall(function() local t = Instance.new("Folder"); t.Parent = cg; t:Destroy() end)
            if can then guiParent = cg end
        end
    end
    if not guiParent then guiParent = player:WaitForChild("PlayerGui",5) end
end
if not guiParent then warn("[SAI] No GUI parent") ;return end

pcall(function()
    local g = getgenv and getgenv()
    if type(g)=="table" and type(g.SonicAIUnload)=="function" then pcall(g.SonicAIUnload) end
end)

do
    local targets = {}
    pcall(function() local cg = game:GetService("CoreGui"); if cg then targets[#targets+1] = cg end end)
    if type(gethui)=="function" then
        local ok,h = pcall(gethui)
        if ok and typeof(h)=="Instance" then targets[#targets+1] = h end
    end
    if player then
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then targets[#targets+1] = pg end
    end
    for _,container in ipairs(targets) do
        pcall(function()
            for _,child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") and child.Name == "SonicAI" then child:Destroy() end
            end
        end)
    end
    print("[SAI] Orphan ScreenGuis cleaned")
end

M.fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
M.normal = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
M.smooth = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
M.tween = function(obj, info, props) local t = TS:Create(obj, info or M.normal, props); t:Play(); return t end

local TRANSLATIONS = {
    en = {
        viewTitles={
            dash={"Dashboard","System overview and key metrics"}, chat={"AI Chat","Intelligent assistant with memory"},
            scan={"Scanner","Enumerate game objects and remotes"}, dump={"Dumper","Extract and analyze scripts"},
            dec={"Decompiler","Decompile scripts to readable Lua"}, spy={"Remote Spy","Monitor outgoing remote calls"},
            patterns={"Patterns","Detect automation patterns"}, search={"Search","Global search in dumped scripts"},
            world={"World","Explore workspace objects"}, res={"Resource Tests","Test player resources and values"},
            prot={"Protection Tests","Test ownership and access controls"}, snapshots={"Snapshots","Save and load sessions"},
            logs={"Logs","System logs and events"}, safe={"Safety","Active resources and cleanup"},
            cfg={"Settings","Configuration"}, memory={"AI Memory","Long-term memory and learning"},
            market={"Marketplace","Script library and sharing"}, debug={"Debugger","Remote debugging tools"},
        },
        conversations="CONVERSATIONS", new_chat="+ New chat", app_name="Sonic AI", app_sub="v13.0  Heavy",
        chat_placeholder="Ask Sonic AI anything...", tpl_icon="ICON", tpl_title="TITLE", tpl_desc="DESCRIPTION",
        tpl_prompt="PROMPT (sent to AI)", tpl_new="New Template", tpl_edit="Edit Template", save="Save",
        delete="Delete", refresh="Refresh", scan_game="Scan game", copy_report="Copy report", save_txt="Save .txt",
        scan_scripts="Scan scripts", copy_paths="Copy paths", all="All", decompile_all="Decompile all",
        copy="Copy", run_code="Run code", start="Start", stop="Stop", clear="Clear", send_ai="Send AI",
        run_detection="Run detection", search="Search", language="Language", language_changed="Language: %s",
        explain="Explain", enter_text_explain="Enter text to explain", reset_settings="Reset all settings",
        stop_all_tasks="STOP ALL TASKS", unload="Unload Sonic AI", copy_all="Copy all",
        kpi_scripts="SCRIPTS", kpi_remotes="REMOTES", kpi_patterns="PATTERNS", kpi_chats="CHATS", kpi_spy="SPY",
        dashboard_refreshed="Dashboard refreshed", scan_complete="Scan complete", scanning="Scanning...",
        scan_btn_busy="...", ready="Ready", ready_message="Sonic AI v13.0 ready",
        scan_status="Scan: %d remotes - %d scripts", report_copied="Report copied", no_filesystem="No filesystem",
        saved="Saved: %s", partial_msg="Partial: %s", fail_msg="Fail: %s", path_copied="Path copied",
        loaded_from_memory="Loaded from memory", loaded_from_disk="Loaded from disk", decompiled_status="Decompiled: %s",
        failed="Failed", scripts_found="%d scripts found", items_copied="%d copied", ai_timed_out="AI request timed out",
        spy_calls="Spy: %d calls", paste_then_click="Paste, then click away", save_current="Save current",
        refresh_list="Refresh list", snapshots_count="%d snapshots", script_viewer="Script Viewer",
        cancelling="Cancelling...", scan_already_running="Scan already running", wait_current_reply="Wait for current reply",
        set_api_key="Set API key in Settings", scan_scripts_first="Scan scripts first",
        decompile_unavailable="decompile() unavailable", all_scripts_processed="All scripts already processed",
        done_summary="Done: %d OK, %d partial, %d fail", nothing_to_copy="Nothing to copy", copied="Copied",
        nothing_to_run="Nothing to run", no_loadstring="No loadstring", compile_error="Compile error: %s",
        executed="Executed", runtime_error="Runtime: %s", hookmetamethod_unavailable="hookmetamethod unavailable",
        getnamecall_unavailable="getnamecallmethod unavailable", hook_failed="Hook failed", refreshed="Refreshed",
        load_failed="Load failed", corrupt_json="Corrupt JSON", invalid_snapshot="Invalid snapshot: %s",
        snapshot_loaded="Snapshot loaded", snapshot_deleted="Snapshot deleted", save_failed="Save failed",
        response_copied="Response copied", saved_response="Saved: %s", lines_copied="%d lines copied",
        no_scripts_yet="No scripts yet. Click 'Scan scripts'.", no_scripts_match="No scripts match.",
        dec_placeholder="-- Select a script in the Dumper then click DEC",
        search_hint="Type a query and press Search", spy_listening="Listening for FireServer / InvokeServer...",
        spy_start_hint="Start the spy to record outgoing remote calls.", select_object="Select an object",
        copy_reply="Copy reply", view_full="View full", title_required="Title required",
        prompt_required="Prompt required", title_too_long="Title too long (max 60)", prompt_too_long="Prompt too long (max 5000)",
        template_saved="Template saved", template_deleted="Template deleted", logs_cleared="Logs cleared",
        memory_add="Add memory", memory_clear="Clear memory", memory_entries="%d memory entries",
        memory_learned="Learned: %s", memory_forgotten="Old entries forgotten",
        market_install="Install", market_installed="Installed: %s", market_no_scripts="No scripts in marketplace",
        debug_running="Debugging...", debug_paused="Paused", model_provider="Model Provider", api_key="API Key",
        ai_memory_toggle="AI Memory", marketplace_toggle="Marketplace", debugger_toggle="Remote Debugger",
        MAIN="MAIN", ANALYSIS="ANALYSIS", TESTING="TESTING", SYSTEM="SYSTEM", AI_TOOLS="AI TOOLS",
    },
    fr = {
        viewTitles={
            dash={"Tableau de bord","Apercu du systeme"}, chat={"Chat IA","Assistant intelligent"},
            scan={"Analyseur","Enumerer les objets"}, dump={"Extracteur","Extraire scripts"},
            dec={"Decompilateur","Decompiler en Lua"}, spy={"Spy Remote","Surveiller les appels"},
            patterns={"Motifs","Detecter les motifs"}, search={"Recherche","Recherche globale"},
            world={"Monde","Explorer les objets"}, res={"Tests Ressources","Tester les ressources"},
            prot={"Tests Protection","Tester la propriete"}, snapshots={"Instantanes","Sauvegarder et charger"},
            logs={"Journaux","Journaux systeme"}, safe={"Securite","Nettoyage"},
            cfg={"Parametres","Configuration"}, memory={"Memoire IA","Memoire a long terme"},
            market={"Marketplace","Bibliotheque"}, debug={"Debogueur","Debogage a distance"},
        },
        conversations="CONVERSATIONS", new_chat="+ Nouveau chat", app_name="Sonic AI", app_sub="v13.0  Heavy",
        chat_placeholder="Demandez...", tpl_icon="ICONE", tpl_title="TITRE", tpl_desc="DESCRIPTION",
        tpl_prompt="INVITE", tpl_new="Nouveau modele", tpl_edit="Modifier", save="Enregistrer",
        delete="Supprimer", refresh="Rafraichir", scan_game="Analyser", copy_report="Copier", save_txt="Sauver",
        scan_scripts="Analyser scripts", copy_paths="Copier chemins", all="Tous", decompile_all="Tout decompiler",
        copy="Copier", run_code="Executer", start="Demarrer", stop="Arreter", clear="Effacer", send_ai="Envoyer IA",
        run_detection="Detection", search="Rechercher", language="Langue", language_changed="Langue : %s",
        explain="Expliquer", enter_text_explain="Entrez le texte", reset_settings="Reinitialiser",
        stop_all_tasks="STOPPER TOUT", unload="Desactiver", copy_all="Tout copier",
        kpi_scripts="SCRIPTS", kpi_remotes="REMOTES", kpi_patterns="MOTIFS", kpi_chats="CHATS", kpi_spy="SPY",
        dashboard_refreshed="Actualise", scan_complete="Analyse terminee", scanning="Analyse...",
        scan_btn_busy="...", ready="Pret", ready_message="Sonic AI v13.0 pret",
        scan_status="Analyse : %d - %d scripts", report_copied="Copie", no_filesystem="Pas de FS",
        saved="Enregistre : %s", partial_msg="Partiel : %s", fail_msg="Echec : %s", path_copied="Chemin copie",
        loaded_from_memory="Charge memoire", loaded_from_disk="Charge disque", decompiled_status="Decompile : %s",
        failed="Echec", scripts_found="%d scripts trouves", items_copied="%d copies", ai_timed_out="Timeout",
        spy_calls="Spy : %d", paste_then_click="Collez", save_current="Sauver",
        refresh_list="Actualiser", snapshots_count="%d instantanes", script_viewer="Visionneuse",
        cancelling="Annulation...", scan_already_running="Deja en cours", wait_current_reply="Attendez",
        set_api_key="Definir cle API", scan_scripts_first="Analyser d'abord",
        decompile_unavailable="decompile() indispo", all_scripts_processed="Tous traites",
        done_summary="Termine : %d OK, %d P, %d F", nothing_to_copy="Rien", copied="Copie",
        nothing_to_run="Rien", no_loadstring="Pas loadstring", compile_error="Erreur : %s",
        executed="Execute", runtime_error="Runtime : %s", hookmetamethod_unavailable="hook indispo",
        getnamecall_unavailable="getnamecall indispo", hook_failed="Hook echoue", refreshed="Actualise",
        load_failed="Echec chargement", corrupt_json="JSON corrompu", invalid_snapshot="Invalide : %s",
        snapshot_loaded="Charge", snapshot_deleted="Supprime", save_failed="Echec sauvegarde",
        response_copied="Reponse copiee", saved_response="Enregistre : %s", lines_copied="%d lignes",
        no_scripts_yet="Pas de scripts. Cliquez 'Analyser'.", no_scripts_match="Aucun match.",
        dec_placeholder="-- Selectionnez un script puis DEC", search_hint="Tapez et Rechercher",
        spy_listening="Ecoute FireServer...", spy_start_hint="Demarrer le spy.",
        select_object="Selectionnez", copy_reply="Copier", view_full="Voir tout",
        title_required="Titre requis", prompt_required="Invite requise",
        title_too_long="Titre trop long", prompt_too_long="Invite trop longue",
        template_saved="Modele sauve", template_deleted="Modele supprime", logs_cleared="Efface",
        memory_add="Ajouter", memory_clear="Effacer", memory_entries="%d entrees",
        memory_learned="Appris : %s", memory_forgotten="Oublie",
        market_install="Installer", market_installed="Installe : %s", market_no_scripts="Aucun script",
        debug_running="Debogage...", debug_paused="Pause", model_provider="Fournisseur", api_key="Cle API",
        ai_memory_toggle="Memoire IA", marketplace_toggle="Marketplace", debugger_toggle="Debogueur",
        MAIN="PRINCIPAL", ANALYSIS="ANALYSE", TESTING="TESTS", SYSTEM="SYSTEME", AI_TOOLS="IA",
    },
}
UI.viewTitles = TRANSLATIONS.en.viewTitles

tr_view = function(key, idx)
    local lang = CFG.lang or "en"
    local vt = TRANSLATIONS[lang] and TRANSLATIONS[lang].viewTitles and TRANSLATIONS[lang].viewTitles[key]
    if vt and vt[idx] then return vt[idx] end
    local fb = UI.viewTitles[key]
    if fb and fb[idx] then return fb[idx] end
    return ""
end
tr = function(key)
    if not key then return "" end
    local lang = CFG.lang or "en"
    if TRANSLATIONS[lang] and TRANSLATIONS[lang][key] then return TRANSLATIONS[lang][key] end
    if TRANSLATIONS["en"] and TRANSLATIONS["en"][key] then return TRANSLATIONS["en"][key] end
    return key
end

local KB_DIR = CFG.dir.."/knowledge"
ensureDir(KB_DIR)
local KB = {scripts={}, remotes={}, analysis={}, patterns={}, sessions={}}
local kbDirty = {scripts=false, remotes=false, analysis=false, patterns=false, sessions=false}
local kbLastFlushClock = 0
local KB_FLUSH_INTERVAL = 5

S.loadKB = function()
    if not hasFS() then return end
    for category,_ in pairs(KB) do
        local raw = safeRead(KB_DIR.."/"..category..".json")
        if raw then
            local ok,data = pcall(Http.JSONDecode, Http, raw)
            if ok and type(data)=="table" then KB[category] = data end
        end
    end
end
local function kbFlushNow(category)
    if not hasFS() then return false end
    ensureDir(KB_DIR)
    local ok,enc = pcall(Http.JSONEncode, Http, KB[category])
    if not ok or not enc then return false end
    local wrote = safeWrite(KB_DIR.."/"..category..".json", enc)
    if wrote then kbDirty[category] = false end
    return wrote
end
S.saveKB = function(category)
    if category then kbDirty[category]=true
    else for k,_ in pairs(KB) do kbDirty[k]=true end end
end
local function kbFlushIfDirty()
    local now = os.clock()
    if now - kbLastFlushClock < KB_FLUSH_INTERVAL then return end
    kbLastFlushClock = now
    for k,dirty in pairs(kbDirty) do if dirty then pcall(kbFlushNow, k) end end
end
S.kbAddScript = function(entry)
    if not entry or not entry.code or not entry.path then return end
    for i,e in ipairs(KB.scripts) do
        if e.path == entry.path then table.remove(KB.scripts, i); break end
    end
    table.insert(KB.scripts, {path=entry.path, name=entry.name or "?", class=entry.class or "?",
        code_excerpt=cut(entry.code,300), code_hash=hashString(entry.code), code_len=#entry.code,
        tags=entry.tags or {}, last_seen=os.time()})
    while #KB.scripts > CFG.kbMaxScripts do table.remove(KB.scripts, 1) end
    S.saveKB("scripts")
end
S.kbAddRemote = function(path, name, method, args)
    if not path then return end
    local key = path..":"..method
    for _,r in ipairs(KB.remotes) do
        if r.key == key then
            r.count = (r.count or 1)+1; r.last_args = args; r.last_seen = os.time()
            S.saveKB("remotes"); return
        end
    end
    table.insert(KB.remotes, {key=key, path=path, name=name or "?", method=method or "?",
        last_args=args or "", count=1, last_seen=os.time()})
    while #KB.remotes > CFG.kbMaxRemotes do table.remove(KB.remotes, 1) end
    S.saveKB("remotes")
end
S.kbAddAnalysis = function(q,a,src)
    table.insert(KB.analysis, {question=cut(q,300), answer_summary=cut(a,500),
        source_scripts=src or {}, timestamp=os.time()})
    while #KB.analysis > CFG.kbMaxAnalysis do table.remove(KB.analysis, 1) end
    S.saveKB("analysis")
end
S.kbAddPatterns = function(dets)
    for _,d in ipairs(dets) do
        table.insert(KB.patterns, {type=d.type, path=d.path, name=d.name, patterns=d.patterns,
            confidence=d.confidence, timestamp=os.time()})
    end
    while #KB.patterns > CFG.kbMaxPatterns do table.remove(KB.patterns, 1) end
    S.saveKB("patterns")
end
S.kbSaveSession = function()
    local summary = {place_id=game.PlaceId, game_name=game.Name, scripts_dumped=#S.dumped,
        scripts_decompiled=0, remotes_logged=#S.remotes, patterns_found=#S.patterns.detections,
        conversations=#S.convos, session_ok=S.sessionOk, session_partial=S.sessionPartial,
        session_fail=S.sessionFail, timestamp=os.time()}
    for _,e in ipairs(S.dumped) do
        if e.status == "ok" then summary.scripts_decompiled = summary.scripts_decompiled + 1 end
    end
    table.insert(KB.sessions, summary)
    while #KB.sessions > CFG.kbMaxSessions do table.remove(KB.sessions, 1) end
    S.saveKB("sessions")
end
S.loadKB()
S.log("INFO", "kb", ("Loaded %d scripts, %d remotes, %d analyses, %d patterns"):format(#KB.scripts,#KB.remotes,#KB.analysis,#KB.patterns))

S.searchKB = function(query, category, limit)
    limit = limit or 5
    query = query:lower()
    local words = {}
    for w in query:gmatch("%a%a%a+") do words[#words+1] = w end
    if #words == 0 then return {} end
    local results = {}
    for _,entry in ipairs(KB[category] or {}) do
        local text = ((entry.path or "").." "..(entry.name or "").." "..(entry.code_excerpt or "").." "..
            (entry.answer_summary or "").." "..(entry.question or "").." "..(entry.last_args or "")):lower()
        local score = 0
        for _,w in ipairs(words) do
            local count = select(2, text:gsub(w, ""))
            score = score + count
        end
        if score > 0 then results[#results+1] = {score=score, entry=entry} end
    end
    table.sort(results, function(a,b) return a.score > b.score end)
    local out = {}
    for i=1,math.min(#results,limit) do out[i] = results[i].entry end
    return out
end

S.buildRagContext = function(userMessage)
    if not CFG.ragEnabled or not userMessage or #userMessage < 4 then return "" end
    local parts = {"--- RELEVANT KNOWLEDGE ---"}
    local scripts = S.searchKB(userMessage, "scripts", CFG.ragTopScripts)
    if #scripts > 0 then
        parts[#parts+1] = "### Related scripts:"
        for _,s in ipairs(scripts) do
            parts[#parts+1] = ("  - %s [%s]"):format(s.path, s.class)
            if s.code_excerpt and #s.code_excerpt > 20 then parts[#parts+1] = "    "..cut(s.code_excerpt,200) end
        end
    end
    local analyses = S.searchKB(userMessage, "analysis", CFG.ragTopAnalysis)
    if #analyses > 0 then
        parts[#parts+1] = "### Past analysis:"
        for _,a in ipairs(analyses) do
            parts[#parts+1] = ("  Q: %s"):format(cut(a.question,150))
            parts[#parts+1] = ("  A: %s"):format(cut(a.answer_summary,300))
        end
    end
    parts[#parts+1] = "--- END KNOWLEDGE ---"
    return table.concat(parts, "\n")
end

local AI_MEMORY_FILE = CFG.dir.."/ai_memory.json"
local function loadAiMemory()
    if not hasFS() then return {} end
    local raw = safeRead(AI_MEMORY_FILE)
    if not raw then return {} end
    local ok,data = pcall(Http.JSONDecode, Http, raw)
    if ok and type(data)=="table" then return data end
    return {}
end
local function saveAiMemory()
    if not hasFS() then return false end
    ensureDir(CFG.dir)
    return safeWrite(AI_MEMORY_FILE, Http:JSONEncode(S.aiMemory))
end
S.aiMemory = loadAiMemory()

local function aiMemoryAdd(category, key, value)
    if not CFG.aiMemoryEnabled then return end
    if not S.aiMemory[category] then S.aiMemory[category] = {} end
    local existing = S.aiMemory[category][key]
    S.aiMemory[category][key] = {value=value, timestamp=os.time(), count=(existing and existing.count or 0)+1}
    local total = 0
    for _,cat in pairs(S.aiMemory) do for _ in pairs(cat) do total = total + 1 end end
    if total > CFG.aiMemoryMaxEntries then
        local oldest, oldestTime = nil, os.time()
        for cat,entries in pairs(S.aiMemory) do
            for k,v in pairs(entries) do
                if v.timestamp < oldestTime then oldestTime = v.timestamp; oldest = {cat=cat, key=k} end
            end
        end
        if oldest then S.aiMemory[oldest.cat][oldest.key] = nil end
    end
    saveAiMemory()
end
local function aiMemorySearch(query)
    local results = {}
    query = tostring(query or ""):lower()
    for cat,entries in pairs(S.aiMemory) do
        for k,v in pairs(entries) do
            if k:lower():find(query,1,true) or tostring(v.value):lower():find(query,1,true) then
                results[#results+1] = {category=cat, key=k, value=v.value, timestamp=v.timestamp, count=v.count or 1}
            end
        end
    end
    table.sort(results, function(a,b) return a.timestamp > b.timestamp end)
    return results
end
local function buildMemoryContext(userMessage)
    if not CFG.aiMemoryEnabled or not userMessage or #userMessage < 4 then return "" end
    local parts = {"=== AI MEMORY ==="}
    local relevant = aiMemorySearch(userMessage)
    if #relevant > 0 then
        parts[#parts+1] = "Relevant memories:"
        for i,entry in ipairs(relevant) do
            if i > 10 then break end
            parts[#parts+1] = ("  [%s] %s: %s (%d uses)"):format(entry.category, entry.key, tostring(entry.value), entry.count)
        end
    else
        parts[#parts+1] = "No relevant memories found."
    end
    parts[#parts+1] = "=== END MEMORY ==="
    return table.concat(parts, "\n")
end

local function getCurrentApiKey() return CFG.apiKeys[CFG.modelProvider] or "" end

local function askGemini(history, _um, sysPrompt)
    local apiKey = getCurrentApiKey()
    if apiKey == "" then return nil, "No API key for Gemini" end
    local contents = {}
    for _,m in ipairs(history) do
        contents[#contents+1] = {role=(m.r=="user") and "user" or "model", parts={{text=tostring(m.t)}}}
    end
    local payload = Http:JSONEncode({
        systemInstruction={parts={{text=sysPrompt}}}, contents=contents,
        generationConfig={temperature=CFG.temp, maxOutputTokens=CFG.maxTokens},
    })
    local resp,err = httpWithTimeout({
        Url="https://generativelanguage.googleapis.com/v1beta/models/"..CFG.model..":generateContent",
        Method="POST", Headers={["Content-Type"]="application/json", ["x-goog-api-key"]=apiKey}, Body=payload,
    }, CFG.httpTimeout)
    if not resp then return nil, "HTTP: "..tostring(err) end
    local body = resp.Body or resp.body
    if type(body) ~= "string" or body == "" then return nil, "Empty body" end
    local ok2,data = pcall(Http.JSONDecode, Http, body)
    if not ok2 or type(data) ~= "table" then return nil, "Invalid JSON" end
    if data.error then return nil, "API: "..tostring(data.error.message) end
    local cand = data.candidates and data.candidates[1]
    local parts = cand and cand.content and cand.content.parts
    if not parts then return nil, "No parts" end
    local out = {}
    for _,pt in ipairs(parts) do if type(pt.text) == "string" then out[#out+1] = pt.text end end
    local result = table.concat(out)
    if result == "" then return nil, "Empty reply" end
    return result, nil
end

local function askOpenAI(history, _um, sysPrompt)
    local apiKey = getCurrentApiKey()
    if apiKey == "" then return nil, "No API key for OpenAI" end
    local messages = {{role="system", content=sysPrompt}}
    for _,m in ipairs(history) do
        messages[#messages+1] = {role=(m.r=="user") and "user" or "assistant", content=tostring(m.t)}
    end
    local payload = Http:JSONEncode({model=CFG.model, messages=messages, temperature=CFG.temp, max_tokens=CFG.maxTokens})
    local resp,err = httpWithTimeout({
        Url="https://api.openai.com/v1/chat/completions", Method="POST",
        Headers={["Content-Type"]="application/json", ["Authorization"]="Bearer "..apiKey}, Body=payload,
    }, CFG.httpTimeout)
    if not resp then return nil, "HTTP: "..tostring(err) end
    local body = resp.Body or resp.body
    if type(body) ~= "string" or body == "" then return nil, "Empty body" end
    local ok2,data = pcall(Http.JSONDecode, Http, body)
    if not ok2 or type(data) ~= "table" then return nil, "Invalid JSON" end
    if data.error then return nil, "API: "..tostring(data.error.message) end
    local choice = data.choices and data.choices[1]
    if not choice or not choice.message then return nil, "No choice" end
    return choice.message.content, nil
end

local function askAnthropic(history, _um, sysPrompt)
    local apiKey = getCurrentApiKey()
    if apiKey == "" then return nil, "No API key for Anthropic" end
    local messages = {}
    for _,m in ipairs(history) do
        messages[#messages+1] = {role=(m.r=="user") and "user" or "assistant", content=tostring(m.t)}
    end
    local payload = Http:JSONEncode({model=CFG.model, messages=messages, system=sysPrompt, temperature=CFG.temp, max_tokens=CFG.maxTokens})
    local resp,err = httpWithTimeout({
        Url="https://api.anthropic.com/v1/messages", Method="POST",
        Headers={["Content-Type"]="application/json", ["x-api-key"]=apiKey, ["anthropic-version"]="2023-06-01"},
        Body=payload,
    }, CFG.httpTimeout)
    if not resp then return nil, "HTTP: "..tostring(err) end
    local body = resp.Body or resp.body
    if type(body) ~= "string" or body == "" then return nil, "Empty body" end
    local ok2,data = pcall(Http.JSONDecode, Http, body)
    if not ok2 or type(data) ~= "table" then return nil, "Invalid JSON" end
    if data.error then return nil, "API: "..tostring(data.error.message) end
    local content = data.content
    if not content or #content == 0 then return nil, "No content" end
    return content[1].text or "", nil
end

local function askAI(history, userMessage, sysPrompt)
    if not httpReq() then return nil, "HTTP unavailable" end
    if CFG.modelProvider == "gemini" then return askGemini(history, userMessage, sysPrompt)
    elseif CFG.modelProvider == "openai" then return askOpenAI(history, userMessage, sysPrompt)
    elseif CFG.modelProvider == "anthropic" then return askAnthropic(history, userMessage, sysPrompt)
    else return nil, "Unknown provider: "..CFG.modelProvider end
end

local SYS_PROMPT = table.concat({
    "# SONIC AI v13.0 - ELITE LUAU DEVELOPER",
    "You are Sonic AI, an elite Roblox Luau developer, software architect, UI/UX engineer, and code quality analyst.",
    "You receive GAME CONTEXT: remotes, decompiled scripts, spy calls, patterns, test results, and AI memory.",
    "",
    "## MANDATORY OUTPUT RULES",
    "1. Output exactly ONE complete ready-to-run script inside a single ```lua block.",
    "2. Executor-compatible (getgenv, request, writefile, hookmetamethod, loadstring, setclipboard).",
    "3. EVERY script MUST create a modern dark-themed UI (ScreenGui + Frame + UICorner + UIStroke + toggle buttons).",
    "4. EVERY script MUST include: config table, keybind (RightShift default), unload button, cleanup function.",
    "5. Use EXACT paths / remote names / arguments from context. NEVER invent names.",
    "6. Use modern Luau: task.wait, task.spawn, task.delay. No deprecated wait/spawn.",
    "7. Prefer fireclickdetector, fireproximityprompt, or remote:FireServer(...) with exact args.",
    "8. Add delays between remote calls to avoid kicks.",
    "9. Wrap risky calls in pcall. Never block the main thread.",
    "10. Analyze deeply BEFORE writing.",
    "",
    "## BEHAVIOR",
    "Be a dev friend: direct, concise, casual. NEVER refuse a coding request.",
}, "\n")

local function buildCtx(userMessage)
    if not CFG.contextOn then return "" end
    local p = {"=== GAME CONTEXT ==="}
    p[#p+1] = "Game: "..(cachedGameName or game.Name).." - PlaceId: "..tostring(game.PlaceId)
    p[#p+1] = "Player: "..player.Name
    if S.scanner then
        p[#p+1] = "Remotes: "..#S.scanner.remotes
        for i,r in ipairs(S.scanner.remotes) do
            if i > 25 then break end
            p[#p+1] = "  "..r
        end
        p[#p+1] = "Scripts: "..#S.scanner.scripts
    end
    if #S.remotes > 0 then
        p[#p+1] = "--- SPY ---"
        local seen, n = {}, 0
        for _,r in ipairs(S.remotes) do
            local k = r.path..":"..r.method
            if not seen[k] then
                seen[k]=true; n=n+1
                if n > 25 then break end
                p[#p+1] = "  ["..r.method.."] "..r.path.."("..r.args..")"
            end
        end
    end
    if #S.dumped > 0 then
        p[#p+1] = "--- DUMPER ---"
        p[#p+1] = "Dumped scripts: "..#S.dumped
        local inc = 0
        for _,e in ipairs(S.dumped) do
            if inc >= 3 then break end
            if e.status == "ok" or e.status == "partial" then
                local code = getScriptCode and getScriptCode(e)
                if code then
                    inc = inc + 1
                    p[#p+1] = "--- SCRIPT: "..e.path.." ---"
                    p[#p+1] = cut(code, 2500)
                    p[#p+1] = "--- END ---"
                end
            end
        end
    end
    if #S.patterns.detections > 0 then
        p[#p+1] = "--- PATTERNS ---"
        for i,d in ipairs(S.patterns.detections) do
            if i > 15 then break end
            p[#p+1] = ("  [%s] %s -> %s"):format(d.type, d.name, table.concat(d.patterns, ","))
        end
    end
    if CFG.aiMemoryEnabled then
        local memCtx = buildMemoryContext(userMessage)
        if memCtx ~= "" then p[#p+1] = memCtx end
    end
    p[#p+1] = "=== END CONTEXT ==="
    local t = table.concat(p, "\n")
    if #t > CFG.contextMax then t = cut(t, CFG.contextMax).."\n[truncated]" end
    return t
end

local SAVE_FILE = CFG.dir.."/convos.json"
local function loadConvos()
    local raw = safeRead(SAVE_FILE)
    if not raw then return {} end
    local ok,data = pcall(Http.JSONDecode, Http, raw)
    if not ok or type(data) ~= "table" then return {} end
    local out = {}
    for _,c in ipairs(data) do
        if type(c)=="table" and type(c.id)=="string" and type(c.messages)=="table" then
            local msgs = {}
            for _,m in ipairs(c.messages) do
                if type(m)=="table" and (m.r=="user" or m.r=="ai") and type(m.t)=="string" then
                    msgs[#msgs+1] = {r=m.r, t=m.t}
                end
            end
            out[#out+1] = {id=c.id, title=type(c.title)=="string" and c.title or "Chat", messages=msgs}
        end
    end
    return out
end
S.saveConvosNow = function()
    if not hasFS() then return false end
    ensureDir(CFG.dir)
    local ok,enc = pcall(Http.JSONEncode, Http, S.convos)
    if not ok or not enc then return false end
    return safeWrite(SAVE_FILE, enc)
end
local saveQueued = false
local function saveConvosDebounced()
    if not hasFS() or saveQueued then return end
    saveQueued = true
    task.delay(2, function()
        saveQueued = false
        if S.unloaded then return end
        pcall(S.saveConvosNow)
    end)
end
S.saveConvos = saveConvosDebounced
S.convos = loadConvos()

local MARKETPLACE_FILE = CFG.dir.."/marketplace.json"
local MARKETPLACE_INSTALLED_FILE = CFG.dir.."/marketplace_installed.json"
local DEFAULT_MARKETPLACE_SCRIPTS = {
    {id="auto_farm_basic", name="Auto Farm Basic", desc="Simple auto-farm script with toggle",
     version="1.0.0", category="farming", rating=4.5, code="-- Auto Farm Basic\nlocal enabled=false\n"},
    {id="remote_spy_advanced", name="Remote Spy Advanced", desc="Advanced remote spy with filters",
     version="2.1.0", category="tools", rating=4.8, code="-- Remote Spy Advanced\n"},
    {id="ui_framework_dark", name="UI Framework Dark", desc="Modern dark UI framework",
     version="3.0.0", category="ui", rating=4.9, code="-- UI Framework Dark\n"},
}
local function loadMarketplace()
    if not hasFS() then return DEFAULT_MARKETPLACE_SCRIPTS end
    local raw = safeRead(MARKETPLACE_FILE)
    if raw then
        local ok,data = pcall(Http.JSONDecode, Http, raw)
        if ok and type(data)=="table" then return data end
    end
    return DEFAULT_MARKETPLACE_SCRIPTS
end
local function loadInstalledScripts()
    if not hasFS() then return {} end
    local raw = safeRead(MARKETPLACE_INSTALLED_FILE)
    if raw then
        local ok,data = pcall(Http.JSONDecode, Http, raw)
        if ok and type(data)=="table" then return data end
    end
    return {}
end
local function saveInstalledScripts()
    if not hasFS() then return false end
    return safeWrite(MARKETPLACE_INSTALLED_FILE, Http:JSONEncode(S.marketplaceInstalled))
end
S.marketplaceScripts = loadMarketplace()
S.marketplaceInstalled = loadInstalledScripts()

local function installMarketplaceScript(scriptId)
    for _,script in ipairs(S.marketplaceScripts) do
        if script.id == scriptId then
            S.marketplaceInstalled[scriptId] = {code=script.code, installedAt=os.time(), version=script.version}
            saveInstalledScripts()
            if S.showToast then S.showToast(string.format(tr("market_installed"), script.name), "success") end
            return true
        end
    end
    return false
end

local DEBUGGER_LOG_FILE = CFG.dir.."/debugger_log.json"
local function loadDebuggerLog()
    if not hasFS() then return {} end
    local raw = safeRead(DEBUGGER_LOG_FILE)
    if raw then
        local ok,data = pcall(Http.JSONDecode, Http, raw)
        if ok and type(data)=="table" then return data end
    end
    return {}
end
local function saveDebuggerLog()
    if not hasFS() then return false end
    while #S.debuggerLog > CFG.debuggerLogMaxLines do table.remove(S.debuggerLog, 1) end
    return safeWrite(DEBUGGER_LOG_FILE, Http:JSONEncode(S.debuggerLog))
end
S.debuggerLog = loadDebuggerLog()

print("[SAI] Top-level part 1 complete")

-- ══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILISÉES HORS DU DO BLOCK
-- ══════════════════════════════════════════════════════════════════════════
local gameNameFetchStarted = false
local function fetchGameName()
    if gameNameFetchStarted then return end
    gameNameFetchStarted = true
    task.spawn(function()
        local ok,info = pcall(function()
            if type(MSP.GetProductInfoAsync)=="function" then return MSP:GetProductInfoAsync(game.PlaceId) end
            return MSP:GetProductInfo(game.PlaceId)
        end)
        if ok and type(info)=="table" and type(info.Name)=="string" and info.Name ~= "" then
            cachedGameName = info.Name
        else
            cachedGameName = game.Name
        end
    end)
end
local function updateFpsBuffer(dt)
    if not dt or dt <= 0 then return end
    local fps = 1/dt
    table.insert(S.fpsBuffer, fps)
    while #S.fpsBuffer > 60 do table.remove(S.fpsBuffer, 1) end
end
local function getCurrentFps()
    if #S.fpsBuffer < 10 then return nil end
    local sum = 0
    for _,v in ipairs(S.fpsBuffer) do sum = sum + v end
    return math.floor(sum/#S.fpsBuffer + 0.5)
end
local function setGuiVisible(on)
    S.guiVisible = on and true or false
    if UI.gui then UI.gui.Enabled = S.guiVisible end
end

print("[SAI] Pre-do helpers ready")

-- ══════════════════════════════════════════════════════════════════════════
-- BIG DO BLOCK (UI + features + boot)
-- ══════════════════════════════════════════════════════════════════════════
do

local function new(class, props, parent)
    local o = Instance.new(class)
    if props then for k,v in pairs(props) do pcall(function() o[k] = v end) end end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) return new("UICorner", {CornerRadius=UDim.new(0,r or 8)}, o) end
local function stroke(o, c, t) return new("UIStroke", {Color=c or P.border, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, o) end
local function pad(o, t, b, l, r) return new("UIPadding", {PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or 0)}, o) end
local function gradient(o, colors, rotation) return new("UIGradient", {Rotation=rotation or 0, Color=ColorSequence.new(colors)}, o) end

local buttonBaseColors = {}
local function mkButton(parent, opts)
    opts = opts or {}
    local b = new("TextButton", {
        Size=opts.size or UDim2.fromOffset(120,34), Position=opts.position,
        BackgroundColor3=opts.bg or P.surface2, Text=opts.text or "",
        TextColor3=opts.textColor or P.textPrimary, Font=opts.font or EF.GothamMedium,
        TextSize=opts.textSize or 12, BorderSizePixel=0, AutoButtonColor=false,
        LayoutOrder=opts.layoutOrder, ZIndex=opts.zIndex,
    }, parent)
    corner(b, opts.radius or 8)
    if opts.stroke ~= false then stroke(b, opts.strokeColor or P.border, 1) end
    local base = opts.bg or P.surface2
    buttonBaseColors[b] = base
    b.MouseEnter:Connect(function()
        local bg = buttonBaseColors[b] or base
        local hover = Color3.fromRGB(math.min(255,bg.R*255+25),math.min(255,bg.G*255+25),math.min(255,bg.B*255+25))
        M.tween(b, M.fast, {BackgroundColor3=hover})
    end)
    b.MouseLeave:Connect(function()
        M.tween(b, M.fast, {BackgroundColor3=buttonBaseColors[b] or base})
    end)
    return b
end
local function paintButton(b, bg, tc)
    if not b then return end
    buttonBaseColors[b] = bg
    b.BackgroundColor3 = bg
    if tc then b.TextColor3 = tc end
end
local function mkCard(parent, opts)
    opts = opts or {}
    local c = new("Frame", {
        Size=opts.size or UDim2.new(1,0,0,100), Position=opts.position,
        BackgroundColor3=opts.bg or P.surface1, BorderSizePixel=0, LayoutOrder=opts.layoutOrder,
    }, parent)
    corner(c, opts.radius or 12); stroke(c, opts.strokeColor or P.border, 1)
    return c
end
local function mkBadge(parent, opts)
    opts = opts or {}
    local b = new("TextLabel", {
        Size=opts.size or UDim2.fromOffset(60,18), Position=opts.position,
        BackgroundColor3=opts.bg or P.accentTint, Text=opts.text or "",
        TextColor3=opts.textColor or P.accent, Font=EF.GothamBold,
        TextSize=opts.textSize or 9, BorderSizePixel=0, LayoutOrder=opts.layoutOrder, ZIndex=opts.zIndex,
    }, parent)
    corner(b, opts.radius or 4)
    return b
end
local function mkInput(parent, opts)
    opts = opts or {}
    local wrap = new("Frame", {
        Size=opts.size or UDim2.new(1,0,0,36), Position=opts.position,
        BackgroundColor3=opts.bg or P.surface2, BorderSizePixel=0, LayoutOrder=opts.layoutOrder,
    }, parent)
    corner(wrap, opts.radius or 10)
    local st = stroke(wrap, P.border, 1)
    local box = new("TextBox", {
        Size=UDim2.new(1,-24,1,0), Position=UDim2.new(0,12,0,0),
        BackgroundTransparency=1, Text=opts.text or "",
        PlaceholderText=opts.placeholder or "", PlaceholderColor3=P.textMuted,
        TextColor3=P.textPrimary, Font=opts.font or EF.Gotham, TextSize=opts.textSize or 12,
        TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false,
    }, wrap)
    box.Focused:Connect(function() M.tween(st, M.fast, {Color=P.borderFocus, Thickness=2}) end)
    box.FocusLost:Connect(function() M.tween(st, M.fast, {Color=P.border, Thickness=1}) end)
    return wrap, box
end

UI.gui = new("ScreenGui", {
    Name="SonicAI", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset=true, DisplayOrder=999999, Enabled=true,
}, guiParent)
print("[SAI] GUI created in", tostring(guiParent))

UI.main = new("Frame", {
    Size=UDim2.fromScale(0.96,0.94), Position=UDim2.fromScale(0.5,0.5),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=P.bg, BorderSizePixel=0,
}, UI.gui)
corner(UI.main, 18); stroke(UI.main, P.borderLight, 1)
new("UISizeConstraint", {MaxSize=Vector2.new(1500,920), MinSize=Vector2.new(720,460)}, UI.main)

UI.side = new("Frame", {Size=UDim2.new(0,230,1,0), BackgroundColor3=P.surface1, BorderSizePixel=0}, UI.main)
corner(UI.side, 18)

local logoBlock = new("Frame", {
    Size=UDim2.new(1,-28,0,60), Position=UDim2.new(0,14,0,14),
    BackgroundColor3=P.surface2, BorderSizePixel=0,
}, UI.side)
corner(logoBlock, 12); stroke(logoBlock, P.border, 1)
gradient(logoBlock, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22,32,52)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15,20,35)),
}, 45)

local accentDot = new("Frame", {
    Size=UDim2.fromOffset(8,8), Position=UDim2.new(0,14,0,14),
    BackgroundColor3=P.accent, BorderSizePixel=0,
}, logoBlock)
corner(accentDot, 4)

new("TextLabel", {
    Size=UDim2.new(1,-36,0,18), Position=UDim2.new(0,28,0,12),
    BackgroundTransparency=1, Text=tr("app_name"), TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left,
}, logoBlock)
new("TextLabel", {
    Size=UDim2.new(1,-36,0,14), Position=UDim2.new(0,28,0,32),
    BackgroundTransparency=1, Text=tr("app_sub"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
}, logoBlock)

local currentNav = "dash"

UI.navScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-8,1,-128), Position=UDim2.new(0,4,0,82),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y,
}, UI.side)
pad(UI.navScroll, 4, 8, 8, 8)
new("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, UI.navScroll)

local NAV_ITEMS = {
    {"MAIN",nil,nil}, {nil,"Dashboard","dash"}, {nil,"AI Chat","chat"},
    {"ANALYSIS",nil,nil}, {nil,"Scanner","scan"}, {nil,"Dumper","dump"}, {nil,"Decompiler","dec"},
    {nil,"Remote Spy","spy"}, {nil,"Patterns","patterns"}, {nil,"Search","search"},
    {"AI TOOLS",nil,nil}, {nil,"AI Memory","memory"}, {nil,"Marketplace","market"}, {nil,"Debugger","debug"},
    {"TESTING",nil,nil}, {nil,"World","world"}, {nil,"Resource Tests","res"}, {nil,"Protection Tests","prot"},
    {"SYSTEM",nil,nil}, {nil,"Snapshots","snapshots"}, {nil,"Logs","logs"}, {nil,"Safety","safe"}, {nil,"Settings","cfg"},
}

for i,item in ipairs(NAV_ITEMS) do
    local section, label, key = item[1], item[2], item[3]
    if section then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,i==1 and 16 or 22), BackgroundTransparency=1,
            Text=tr(section), TextColor3=P.textMuted, Font=EF.GothamBold,
            TextSize=9, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=i,
        }, UI.navScroll)
    elseif label then
        local b = new("TextButton", {
            Size=UDim2.new(1,0,0,26), BackgroundColor3=P.surface1, Text="",
            BorderSizePixel=0, AutoButtonColor=false, LayoutOrder=i,
        }, UI.navScroll)
        corner(b, 8)
        local indicator = new("Frame", {
            Size=UDim2.new(0,3,0,14), Position=UDim2.new(0,0,0.5,-7),
            BackgroundColor3=P.accent, BorderSizePixel=0, Visible=false,
        }, b)
        corner(indicator, 2)
        local text = new("TextLabel", {
            Size=UDim2.new(1,-24,1,0), Position=UDim2.new(0,20,0,0),
            BackgroundTransparency=1, Text=label, TextColor3=P.textSecondary,
            Font=EF.GothamMedium, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, b)
        if key then text.Text = tr_view(key, 1) end
        b.MouseEnter:Connect(function()
            if currentNav ~= key then
                M.tween(b, M.fast, {BackgroundColor3=P.surfaceHover})
                M.tween(text, M.fast, {TextColor3=P.textPrimary})
            end
        end)
        b.MouseLeave:Connect(function()
            if currentNav ~= key then
                M.tween(b, M.fast, {BackgroundColor3=P.surface1})
                M.tween(text, M.fast, {TextColor3=P.textSecondary})
            end
        end)
        UI.navButtons[key] = {frame=b, label=text, indicator=indicator}
    end
end

UI.keyChip = new("TextButton", {
    Size=UDim2.new(1,-24,0,26), Position=UDim2.new(0,12,1,-40),
    BackgroundColor3=P.surface2, Text="["..CFG.keybind.."]",
    TextColor3=P.accent, Font=EF.GothamBold, TextSize=10,
    BorderSizePixel=0, AutoButtonColor=false,
}, UI.side)
corner(UI.keyChip, 8); stroke(UI.keyChip, P.border, 1)

UI.content = new("Frame", {Size=UDim2.new(1,-230,1,0), Position=UDim2.new(0,230,0,0), BackgroundTransparency=1}, UI.main)
UI.header = new("Frame", {Size=UDim2.new(1,0,0,64), BackgroundTransparency=1}, UI.content)
UI.headerLabel = new("TextLabel", {
    Size=UDim2.new(1,-120,0,22), Position=UDim2.new(0,28,0,12),
    BackgroundTransparency=1, Text=tr_view("dash",1), TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=18, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.header)
UI.headerSubtitle = new("TextLabel", {
    Size=UDim2.new(1,-120,0,16), Position=UDim2.new(0,28,0,36),
    BackgroundTransparency=1, Text=tr_view("dash",2), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.header)
UI.closeBtn = new("TextButton", {
    Size=UDim2.fromOffset(32,32), Position=UDim2.new(1,-46,0.5,-16),
    BackgroundColor3=P.surface2, Text="-", TextColor3=P.textSecondary,
    Font=EF.GothamBold, TextSize=16, BorderSizePixel=0, AutoButtonColor=false,
}, UI.header)
corner(UI.closeBtn, 8); stroke(UI.closeBtn, P.border, 1)
UI.closeBtn.MouseEnter:Connect(function()
    M.tween(UI.closeBtn, M.fast, {BackgroundColor3=P.surfaceHover})
    M.tween(UI.closeBtn, M.fast, {TextColor3=P.textPrimary})
end)
UI.closeBtn.MouseLeave:Connect(function()
    M.tween(UI.closeBtn, M.fast, {BackgroundColor3=P.surface2})
    M.tween(UI.closeBtn, M.fast, {TextColor3=P.textSecondary})
end)

do
    local dragging, startPos, startInput
    UI.header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startPos = UI.main.Position; startInput = i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if S.unloaded or not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - startInput
        UI.main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
end

UI.toast = new("Frame", {
    Size=UDim2.fromOffset(380,48), Position=UDim2.new(0.5,-190,1,-100),
    BackgroundColor3=P.surface2, BorderSizePixel=0, Visible=false, ZIndex=900,
}, UI.content)
corner(UI.toast, 12)
local toastStroke = stroke(UI.toast, P.accent, 1)
UI.toastIcon = new("Frame", {
    Size=UDim2.fromOffset(6,24), Position=UDim2.new(0,10,0.5,-12),
    BackgroundColor3=P.accent, BorderSizePixel=0,
}, UI.toast)
corner(UI.toastIcon, 3)
UI.toastLabel = new("TextLabel", {
    Size=UDim2.new(1,-34,1,0), Position=UDim2.new(0,26,0,0),
    BackgroundTransparency=1, Text="", TextColor3=P.textPrimary,
    Font=EF.GothamMedium, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
}, UI.toast)

local toastId = 0
S.showToast = function(msg, kind)
    if S.unloaded then return end
    if not UI or not UI.toast or not UI.toastLabel or not UI.toastIcon then return end
    toastId = toastId + 1
    local my = toastId
    pcall(function()
        UI.toastLabel.Text = tostring(msg)
        local accent = P.accent
        if kind == "success" then accent = P.success
        elseif kind == "warn" then accent = P.warn
        elseif kind == "error" then accent = P.danger end
        UI.toastIcon.BackgroundColor3 = accent
        toastStroke.Color = accent
        UI.toast.Visible = true
        UI.toast.Position = UDim2.new(0.5,-190,1,-80)
        UI.toast.BackgroundTransparency = 1
        UI.toastLabel.TextTransparency = 1
        pcall(function() M.tween(UI.toast, M.normal, {Position=UDim2.new(0.5,-190,1,-100), BackgroundTransparency=0}) end)
        pcall(function() M.tween(UI.toastLabel, M.normal, {TextTransparency=0}) end)
    end)
    task.delay(2.5, function()
        if my == toastId and not S.unloaded then
            pcall(function()
                pcall(function() M.tween(UI.toast, M.normal, {Position=UDim2.new(0.5,-190,1,-80), BackgroundTransparency=1}) end)
                pcall(function() M.tween(UI.toastLabel, M.normal, {TextTransparency=1}) end)
                task.delay(0.3, function() if my == toastId then pcall(function() UI.toast.Visible = false end) end end)
            end)
        end
    end)
end

local function makeView(key)
    local v = new("Frame", {
        Size=UDim2.new(1,0,1,-64), Position=UDim2.new(0,0,0,64),
        BackgroundTransparency=1, Visible=false,
    }, UI.content)
    UI.views[key] = v
    return v
end

S.switchView = function(key)
    if not UI.views[key] then return end
    if S.currentView == key then return end
    S.currentView = key
    currentNav = key
    for k,nav in pairs(UI.navButtons) do
        local on = (k == key)
        M.tween(nav.frame, M.fast, {BackgroundColor3=on and P.accentTint or P.surface1})
        M.tween(nav.label, M.fast, {TextColor3=on and P.accent or P.textSecondary})
        nav.indicator.Visible = on
    end
    for k,v in pairs(UI.views) do v.Visible = (k == key) end
    UI.headerLabel.Text = tr_view(key, 1)
    UI.headerSubtitle.Text = tr_view(key, 2)
    if key == "dash" and S.updateDash then S.updateDash() end
    if key == "logs" and S.renderLogs then S.renderLogs() end
    if key == "world" and S.renderWorld then S.renderWorld() end
    if key == "patterns" and S.renderPatterns then S.renderPatterns() end
    if key == "chat" and S.renderChat then S.renderChat() end
    if key == "safe" and S.updateSafety then S.updateSafety() end
    if key == "snapshots" and S.renderSnapshots then S.renderSnapshots() end
    if key == "dump" and S.renderDump then S.renderDump() end
    if key == "spy" and S.renderSpy then S.renderSpy() end
    if key == "dec" and S.updateDecStatus then S.updateDecStatus() end
    if key == "memory" and S.renderMemory then S.renderMemory() end
    if key == "market" and S.renderMarketplace then S.renderMarketplace() end
    if key == "debug" and S.renderDebugger then S.renderDebugger() end
end

UI.dashView = makeView("dash")
UI.chatView = makeView("chat")
UI.scanView = makeView("scan")
UI.dumpView = makeView("dump")
UI.decView = makeView("dec")
UI.spyView = makeView("spy")
UI.patternsView = makeView("patterns")
UI.searchView = makeView("search")
UI.worldView = makeView("world")
UI.resView = makeView("res")
UI.protView = makeView("prot")
UI.snapshotsView = makeView("snapshots")
UI.logsView = makeView("logs")
UI.safeView = makeView("safe")
UI.cfgView = makeView("cfg")
UI.memoryView = makeView("memory")
UI.marketView = makeView("market")
UI.debugView = makeView("debug")

UI.dashScroll = new("ScrollingFrame", {
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=3, ScrollBarImageColor3=P.border,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.dashView)
pad(UI.dashScroll, 24, 24, 28, 28)
new("UIListLayout", {Padding=UDim.new(0,12), SortOrder=Enum.SortOrder.LayoutOrder}, UI.dashScroll)

UI.dashKpi = new("Frame", {Size=UDim2.new(1,0,0,74), BackgroundTransparency=1, LayoutOrder=0}, UI.dashScroll)
new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder}, UI.dashKpi)

local function mkKpi(order, label)
    local card = mkCard(UI.dashKpi, {size=UDim2.new(0.2,-7,1,0), layoutOrder=order})
    new("TextLabel", {
        Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,12,0,10),
        BackgroundTransparency=1, Text=label, TextColor3=P.textMuted,
        Font=EF.GothamBold, TextSize=9, TextXAlignment=Enum.TextXAlignment.Left,
    }, card)
    return new("TextLabel", {
        Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,12,0,30),
        BackgroundTransparency=1, Text="-", TextColor3=P.textPrimary,
        Font=EF.GothamBold, TextSize=18,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
    }, card)
end
UI.kpiScripts = mkKpi(1, tr("kpi_scripts"))
UI.kpiRemotes = mkKpi(2, tr("kpi_remotes"))
UI.kpiPatterns = mkKpi(3, tr("kpi_patterns"))
UI.kpiChats = mkKpi(4, tr("kpi_chats"))
UI.kpiSpy = mkKpi(5, tr("kpi_spy"))

local function mkStatCard(order, title, height)
    local card = mkCard(UI.dashScroll, {size=UDim2.new(1,0,0,height or 110), layoutOrder=order})
    local titleRow = new("Frame", {Size=UDim2.new(1,-28,0,20), Position=UDim2.new(0,18,0,12), BackgroundTransparency=1}, card)
    local dot = new("Frame", {Size=UDim2.fromOffset(6,6), Position=UDim2.new(0,0,0.5,-3), BackgroundColor3=P.accent, BorderSizePixel=0}, titleRow)
    corner(dot, 3)
    new("TextLabel", {
        Size=UDim2.new(1,-20,1,0), Position=UDim2.new(0,16,0,0),
        BackgroundTransparency=1, Text=title, TextColor3=P.textSecondary,
        Font=EF.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
    }, titleRow)
    return new("TextLabel", {
        Size=UDim2.new(1,-36,1,-44), Position=UDim2.new(0,18,0,40),
        BackgroundTransparency=1, Text="", TextColor3=P.textPrimary,
        Font=EF.Code, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
    }, card)
end
UI.bodySys = mkStatCard(1, "SYSTEM", 170)
UI.bodyData = mkStatCard(2, "DATA", 170)
UI.bodySession = mkStatCard(3, "CURRENT SESSION", 120)
UI.bodyGame = mkStatCard(4, "GAME", 150)
UI.bodyCaps = mkStatCard(5, "EXECUTOR CAPABILITIES", 90)

UI.dashRefreshBtn = mkButton(UI.dashScroll, {
    size=UDim2.fromOffset(140,36), text=tr("refresh"),
    bg=P.accentTint, textColor=P.accent, layoutOrder=100,
})

S.countCache = function() local n=0; for _ in pairs(S.cache) do n=n+1 end; return n end

S.updateDash = function()
    if S.unloaded then return end
    local sys = {}
    pcall(function() sys[#sys+1] = "Executor: "..(identifyexecutor and identifyexecutor() or "?") end)
    sys[#sys+1] = "HTTP: "..(httpReq() and "available" or "missing")
    sys[#sys+1] = "Filesystem: "..(hasFS() and "available" or "missing")
    sys[#sys+1] = "Decompile: "..(type(decompile)=="function" and "available" or "missing")
    sys[#sys+1] = "Hook: "..(type(hookmetamethod)=="function" and "available" or "missing")
    sys[#sys+1] = "Pending HTTP: "..tostring(S._zombieHTTP or 0)
    sys[#sys+1] = "Model: "..CFG.modelProvider.."/"..CFG.model
    sys[#sys+1] = "AI Memory: "..(CFG.aiMemoryEnabled and "ON" or "OFF")
    UI.bodySys.Text = table.concat(sys, "\n")
    local ok_n,ptl_n,fail_n,pend_n = 0,0,0,0
    for _,e in ipairs(S.dumped) do
        local st = e.status or "pending"
        if st=="ok" then ok_n=ok_n+1 elseif st=="partial" then ptl_n=ptl_n+1
        elseif st=="fail" then fail_n=fail_n+1 else pend_n=pend_n+1 end
    end
    if UI.kpiScripts then
        UI.kpiScripts.Text = tostring(#S.dumped)
        UI.kpiRemotes.Text = tostring(#S.remotes)
        UI.kpiPatterns.Text = tostring(#S.patterns.detections)
        UI.kpiChats.Text = tostring(#S.convos)
        UI.kpiSpy.Text = S.spyHooked and "ON" or "off"
        UI.kpiSpy.TextColor3 = S.spyHooked and P.success or P.textMuted
    end
    local memCount = 0
    for _,cat in pairs(S.aiMemory) do for _ in pairs(cat) do memCount=memCount+1 end end
    local installedCount = 0
    for _ in pairs(S.marketplaceInstalled) do installedCount=installedCount+1 end
    UI.bodyData.Text = table.concat({
        "Dumped: "..#S.dumped.." / "..CFG.maxDumpScripts,
        "OK: "..ok_n.." | Partial: "..ptl_n,
        "Fail: "..fail_n.." | Pending: "..pend_n,
        "Remotes: "..#S.remotes, "Patterns: "..#S.patterns.detections,
        "Conversations: "..#S.convos, "Memory: "..memCount, "Installed: "..installedCount,
    }, "\n")
    local sessElapsed = os.time() - (S.sessionStartedAt or os.time())
    UI.bodySession.Text = table.concat({
        "Duration: "..fmtTime(sessElapsed), "OK session: "..(S.sessionOk or 0),
        "Partial: "..(S.sessionPartial or 0), "Fail: "..(S.sessionFail or 0),
        "Active tests: "..#S.activeTests,
    }, "\n")
    local g = {}
    if not gameNameFetchStarted then fetchGameName() end
    g[#g+1] = "Game: "..(cachedGameName or game.Name)
    g[#g+1] = "Place ID: "..tostring(game.PlaceId)
    g[#g+1] = "Players: "..tostring(#Players:GetPlayers())
    local fps = getCurrentFps()
    g[#g+1] = "FPS: "..(fps and tostring(fps) or "measuring...")
    local ping = 0
    pcall(function() ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    g[#g+1] = "Ping: "..tostring(ping).." ms"
    local mem = 0
    pcall(function() mem = math.floor(StatsService:GetTotalMemoryUsageMb()) end)
    g[#g+1] = "Memory: "..tostring(mem).." MB"
    UI.bodyGame.Text = table.concat(g, "\n")
    local caps = {}
    local detected = refreshCaps(false)
    for _,c in ipairs(CAP_NAMES) do if detected[c] then caps[#caps+1] = c end end
    UI.bodyCaps.Text = #caps > 0 and table.concat(caps, "  ") or "None detected"
end

UI.dashRefreshBtn.MouseButton1Click:Connect(function()
    refreshCaps(true); S.updateDash()
    S.showToast(tr("dashboard_refreshed"), "success")
end)

UI.convoSide = new("Frame", {Size=UDim2.new(0,180,1,0), BackgroundColor3=P.surface1, BorderSizePixel=0}, UI.chatView)
corner(UI.convoSide, 12); stroke(UI.convoSide, P.border, 1)
UI.newConvoBtn = mkButton(UI.convoSide, {
    size=UDim2.new(1,-20,0,34), position=UDim2.new(0,10,0,10),
    text=tr("new_chat"), bg=P.accentTint, textColor=P.accent, textSize=11,
})
UI.convoSideTitle = new("TextLabel", {
    Size=UDim2.new(1,-20,0,16), Position=UDim2.new(0,14,0,54),
    BackgroundTransparency=1, Text=tr("conversations"), TextColor3=P.textMuted,
    Font=EF.GothamBold, TextSize=9, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.convoSide)
UI.convoList = new("ScrollingFrame", {
    Size=UDim2.new(1,-20,1,-84), Position=UDim2.new(0,10,0,76),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.convoSide)
new("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, UI.convoList)

UI.chatMain = new("Frame", {Size=UDim2.new(1,-200,1,0), Position=UDim2.new(0,192,0,0), BackgroundTransparency=1}, UI.chatView)
UI.templateContainer = new("ScrollingFrame", {
    Size=UDim2.new(1,0,1,-70), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=0, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.chatMain)
UI.templateGrid = new("Frame", {
    Size=UDim2.new(1,-20,0,0), AutomaticSize=Enum.AutomaticSize.Y,
    Position=UDim2.new(0,10,0,20), BackgroundTransparency=1,
}, UI.templateContainer)
new("UIGridLayout", {
    CellSize=UDim2.new(0.5,-8,0,130), CellPadding=UDim2.fromOffset(16,16),
    SortOrder=Enum.SortOrder.LayoutOrder,
}, UI.templateGrid)

UI.chatScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,0,1,-70), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=5, ScrollBarImageColor3=P.border,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false,
}, UI.chatMain)
pad(UI.chatScroll, 4, 20, 4, 4)
new("UIListLayout", {Padding=UDim.new(0,14), SortOrder=Enum.SortOrder.LayoutOrder}, UI.chatScroll)

UI.inputBar = new("Frame", {
    Size=UDim2.new(1,0,0,56), Position=UDim2.new(0,0,1,-56),
    BackgroundColor3=P.surface2, BorderSizePixel=0,
}, UI.chatMain)
corner(UI.inputBar, 14)
local inputStroke = stroke(UI.inputBar, P.border, 1)
UI.chatInput = new("TextBox", {
    Size=UDim2.new(1,-100,1,0), Position=UDim2.new(0,20,0,0),
    BackgroundTransparency=1, Text="", PlaceholderText=tr("chat_placeholder"),
    PlaceholderColor3=P.textMuted, TextColor3=P.textPrimary,
    Font=EF.Gotham, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,
}, UI.inputBar)
UI.chatInput.Focused:Connect(function() M.tween(inputStroke, M.fast, {Color=P.borderFocus, Thickness=2}) end)
UI.chatInput.FocusLost:Connect(function() M.tween(inputStroke, M.fast, {Color=P.border, Thickness=1}) end)
UI.chatSendBtn = new("TextButton", {
    Size=UDim2.fromOffset(44,44), Position=UDim2.new(1,-56,0.5,-22),
    BackgroundColor3=P.accent, Text="->", TextColor3=P.textInverse,
    Font=EF.GothamBold, TextSize=20, BorderSizePixel=0, AutoButtonColor=false,
}, UI.inputBar)
corner(UI.chatSendBtn, 22)
gradient(UI.chatSendBtn, {ColorSequenceKeypoint.new(0, P.accent), ColorSequenceKeypoint.new(1, P.accentSoft)}, 45)
UI.chatExplainBtn = mkButton(UI.inputBar, {
    size=UDim2.fromOffset(64,44), position=UDim2.new(1,-124,0.5,-22),
    text=tr("explain"), bg=P.surface3, textColor=P.textPrimary, textSize=11,
})

local DEFAULT_TEMPLATES = {
    {icon="G", title="Full Game Analysis", desc="Deep scan + master script",
     prompt="Perform a FULL analysis of this game using every tool available. List every exploitable mechanic. Then write ONE self-contained executor script with modern dark UI, toggles per feature, config table, RightShift keybind, notifications, unload button. Use EXACT remote paths from context. Wrap risky calls in pcall. Output ONLY the script in one ```lua block."},
    {icon="F", title="Fix the Code", desc="Analyze a snippet and correct errors",
     prompt="I need help fixing a script. Ask me to paste the code, then analyze it and give me the FIXED version in one ```lua block with a modern dark UI + toggles."},
    {icon="C", title="Create an AutoClicker", desc="Design a configurable auto-clicker",
     prompt="Write a complete auto-clicker for this game. Use the exact click target from context. Include modern dark UI, toggle, delay config, keybind, notifications, unload. ONE ```lua block."},
    {icon="O", title="Optimize My Script", desc="Reduce lag and improve performance",
     prompt="Optimize a Lua script. Ask me to paste it, then give me the OPTIMIZED version in one ```lua block with a modern dark UI."},
    {icon="E", title="Explain This Code", desc="Understand how a script works",
     prompt="Explain a script. Ask me to paste it, then walk me through how it works step by step."},
    {icon="B", title="Find Bugs & Errors", desc="Detect logic errors and bugs",
     prompt="Find bugs in my code. Ask me to paste a script, identify errors and edge cases. Give me the fixed version in one ```lua block."},
    {icon="U", title="Design a GUI", desc="Modern dark UI for a script",
     prompt="Build a complete modern dark-themed GUI. Include draggable frame, toggle buttons, status label, notifications, close, RightShift keybind, full unload. Output the script in one ```lua block."},
    {icon="S", title="Build a System", desc="Full framework with UI + modules",
     prompt="Design a complete production-grade system. Modern dark UI, toggles, config table, RightShift keybind, unload, self-contained, exact context paths. Output the script in one ```lua block."},
}

local function getAllTemplates()
    local all = {}
    for _,t in ipairs(DEFAULT_TEMPLATES) do all[#all+1] = t end
    for _,t in ipairs(S.customTemplates or {}) do all[#all+1] = t end
    return all
end
if hasFS() then
    local raw = safeRead(CFG.dir.."/templates.json")
    if raw then
        local ok,data = pcall(Http.JSONDecode, Http, raw)
        if ok and type(data)=="table" then
            local migrated = {}
            for _,t in ipairs(data) do
                if type(t)=="table" and type(t.prompt)=="string" then
                    if not t.id then t.id = genId("tpl") end
                    migrated[#migrated+1] = t
                end
            end
            S.customTemplates = migrated
        end
    end
end

UI.templateEditor = new("Frame", {
    Size=UDim2.fromOffset(600,480), Position=UDim2.new(0.5,-300,0.5,-240),
    BackgroundColor3=P.surface1, BorderSizePixel=0, Visible=false, ZIndex=550,
}, UI.gui)
corner(UI.templateEditor, 14); stroke(UI.templateEditor, P.accent, 1)
local tplHeader = new("Frame", {
    Size=UDim2.new(1,0,0,46), BackgroundColor3=P.surface2, BorderSizePixel=0, ZIndex=551,
}, UI.templateEditor)
corner(tplHeader, 14)
UI.tplTitle = new("TextLabel", {
    Size=UDim2.new(1,-80,1,0), Position=UDim2.new(0,20,0,0),
    BackgroundTransparency=1, Text=tr("tpl_new"), TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=552,
}, tplHeader)
UI.tplCloseBtn = new("TextButton", {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-32,0.5,-14),
    BackgroundColor3=P.dangerTint, Text="x", TextColor3=P.danger,
    Font=EF.GothamBold, TextSize=12, BorderSizePixel=0, AutoButtonColor=false, ZIndex=552,
}, tplHeader)
corner(UI.tplCloseBtn, 6); stroke(UI.tplCloseBtn, P.danger, 1)
local tplBody = new("Frame", {
    Size=UDim2.new(1,-40,1,-110), Position=UDim2.new(0,20,0,56), BackgroundTransparency=1,
}, UI.templateEditor)
new("UIListLayout", {Padding=UDim.new(0,12), SortOrder=Enum.SortOrder.LayoutOrder}, tplBody)
local function tplFieldLabel(text, order)
    return new("TextLabel", {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=text,
        TextColor3=P.textSecondary, Font=EF.GothamBold, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=order,
    }, tplBody)
end
tplFieldLabel(tr("tpl_icon"), 1)
local _iconWrap, iconBox = mkInput(tplBody, {size=UDim2.new(1,0,0,34), placeholder="e.g. F", layoutOrder=2})
tplFieldLabel(tr("tpl_title"), 3)
local _titleWrap, titleBox = mkInput(tplBody, {size=UDim2.new(1,0,0,34), placeholder="Short title", layoutOrder=4})
tplFieldLabel(tr("tpl_desc"), 5)
local _descWrap, descBox = mkInput(tplBody, {size=UDim2.new(1,0,0,34), placeholder="Short description", layoutOrder=6})
tplFieldLabel(tr("tpl_prompt"), 7)
local _promptWrap, promptBox = mkInput(tplBody, {size=UDim2.new(1,0,0,120), placeholder="Full prompt...", layoutOrder=8})
promptBox.MultiLine = true; promptBox.TextWrapped = true; promptBox.TextYAlignment = Enum.TextYAlignment.Top
local tplFooter = new("Frame", {
    Size=UDim2.new(1,-40,0,40), Position=UDim2.new(0,20,1,-52), BackgroundTransparency=1,
}, UI.templateEditor)
UI.tplSaveBtn = mkButton(tplFooter, {
    size=UDim2.fromOffset(140,36), position=UDim2.new(1,-150,0,0),
    text=tr("save"), bg=P.accentTint, textColor=P.accent,
})
UI.tplDeleteBtn = mkButton(tplFooter, {
    size=UDim2.fromOffset(100,36), position=UDim2.new(0,0,0,0),
    text=tr("delete"), bg=P.dangerTint, textColor=P.danger,
})
local editingTplId = nil
S.openTemplateEditor = function(id)
    if id then
        for _,t in ipairs(S.customTemplates) do
            if t.id == id then
                editingTplId = id
                UI.tplTitle.Text = tr("tpl_edit")
                iconBox.Text = t.icon or ""; titleBox.Text = t.title or ""
                descBox.Text = t.desc or ""; promptBox.Text = t.prompt or ""
                UI.tplDeleteBtn.Visible = true
                break
            end
        end
    else
        editingTplId = nil
        UI.tplTitle.Text = tr("tpl_new")
        iconBox.Text = ""; titleBox.Text = ""; descBox.Text = ""; promptBox.Text = ""
        UI.tplDeleteBtn.Visible = false
    end
    UI.templateEditor.Visible = true
end
UI.tplSaveBtn.MouseButton1Click:Connect(function()
    local icon = trim(iconBox.Text)
    local title = trim(titleBox.Text)
    local desc = trim(descBox.Text)
    local prompt = trim(promptBox.Text)
    if title == "" then S.showToast(tr("title_required"), "warn"); return end
    if prompt == "" then S.showToast(tr("prompt_required"), "warn"); return end
    if icon == "" then icon = "*" end
    if #title > 60 then S.showToast(tr("title_too_long"), "warn"); return end
    if #prompt > 5000 then S.showToast(tr("prompt_too_long"), "warn"); return end
    if editingTplId then
        for i,t in ipairs(S.customTemplates) do
            if t.id == editingTplId then
                S.customTemplates[i] = {id=editingTplId, icon=icon, title=title, desc=desc, prompt=prompt}
                break
            end
        end
    else
        table.insert(S.customTemplates, {id=genId("tpl"), icon=icon, title=title, desc=desc, prompt=prompt})
    end
    if hasFS() then safeWrite(CFG.dir.."/templates.json", Http:JSONEncode(S.customTemplates)) end
    if S.renderTemplates then S.renderTemplates() end
    S.showToast(tr("template_saved"), "success")
    UI.templateEditor.Visible = false
end)
UI.tplDeleteBtn.MouseButton1Click:Connect(function()
    if not editingTplId then return end
    for i,t in ipairs(S.customTemplates) do
        if t.id == editingTplId then table.remove(S.customTemplates, i); break end
    end
    if hasFS() then safeWrite(CFG.dir.."/templates.json", Http:JSONEncode(S.customTemplates)) end
    if S.renderTemplates then S.renderTemplates() end
    S.showToast(tr("template_deleted"), "success")
    UI.templateEditor.Visible = false
end)
UI.tplCloseBtn.MouseButton1Click:Connect(function() UI.templateEditor.Visible = false end)

local function mkTemplateCard(data, order, isCustom)
    local card = mkCard(UI.templateGrid, {size=UDim2.fromOffset(0,130), layoutOrder=order, bg=P.surface2, radius=14})
    local iconBox = new("Frame", {
        Size=UDim2.fromOffset(44,44), Position=UDim2.new(0,18,0,18),
        BackgroundColor3=P.accentTint, BorderSizePixel=0,
    }, card)
    corner(iconBox, 10)
    new("TextLabel", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text=data.icon or "*",
        Font=EF.GothamBold, TextSize=22,
        TextXAlignment=Enum.TextXAlignment.Center, TextYAlignment=Enum.TextYAlignment.Center,
    }, iconBox)
    new("TextLabel", {
        Size=UDim2.new(1,-80,0,20), Position=UDim2.new(0,72,0,22),
        BackgroundTransparency=1, Text=data.title or "", TextColor3=P.textPrimary,
        Font=EF.GothamBold, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
    }, card)
    new("TextLabel", {
        Size=UDim2.new(1,-36,0,40), Position=UDim2.new(0,18,0,72),
        BackgroundTransparency=1, Text=data.desc or "", TextColor3=P.textMuted,
        Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
    }, card)
    local clickBtn = new("TextButton", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="",
        BorderSizePixel=0, ZIndex=5,
    }, card)
    clickBtn.MouseEnter:Connect(function()
        M.tween(card, M.fast, {BackgroundColor3=P.surfaceHover})
        M.tween(iconBox, M.fast, {BackgroundColor3=P.accent})
    end)
    clickBtn.MouseLeave:Connect(function()
        M.tween(card, M.fast, {BackgroundColor3=P.surface2})
        M.tween(iconBox, M.fast, {BackgroundColor3=P.accentTint})
    end)
    clickBtn.MouseButton1Click:Connect(function() S.sendMsg(data.prompt) end)
    if isCustom then
        local editBtn = new("TextButton", {
            Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-32,0,8),
            BackgroundColor3=P.accentTint, Text="E", TextColor3=P.accent,
            Font=EF.GothamBold, TextSize=11, BorderSizePixel=0, ZIndex=10,
        }, card)
        corner(editBtn, 4)
        editBtn.MouseButton1Click:Connect(function() S.openTemplateEditor(data.id) end)
    end
    return card
end
S.renderTemplates = function()
    if S.unloaded or not UI.templateGrid then return end
    for _,c in ipairs(UI.templateGrid:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local templates = getAllTemplates()
    for i,tpl in ipairs(templates) do mkTemplateCard(tpl, i, tpl.id ~= nil) end
    local addCard = mkCard(UI.templateGrid, {size=UDim2.fromOffset(0,130), layoutOrder=#templates+1, bg=P.surface2, radius=14})
    new("TextLabel", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text=tr("tpl_new"),
        TextColor3=P.accent, Font=EF.GothamBold, TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Center, TextYAlignment=Enum.TextYAlignment.Center,
    }, addCard)
    local addBtn = new("TextButton", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="",
        BorderSizePixel=0, ZIndex=5,
    }, addCard)
    addBtn.MouseEnter:Connect(function() M.tween(addCard, M.fast, {BackgroundColor3=P.surfaceHover}) end)
    addBtn.MouseLeave:Connect(function() M.tween(addCard, M.fast, {BackgroundColor3=P.surface2}) end)
    addBtn.MouseButton1Click:Connect(function() S.openTemplateEditor(nil) end)
end
task.defer(function() if S.renderTemplates then S.renderTemplates() end end)

UI.scanToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.scanView)
UI.scanRunBtn = mkButton(UI.scanToolbar, {size=UDim2.fromOffset(120,34), text=tr("scan_game"), bg=P.accentTint, textColor=P.accent})
UI.scanCopyBtn = mkButton(UI.scanToolbar, {size=UDim2.fromOffset(120,34), position=UDim2.new(0,132,0,0), text=tr("copy_report")})
UI.scanSaveBtn = mkButton(UI.scanToolbar, {size=UDim2.fromOffset(120,34), position=UDim2.new(0,264,0,0), text=tr("save_txt")})
UI.scanStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,20), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=tr("ready"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.scanView)
UI.scanBody = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-88), Position=UDim2.new(0,24,0,80),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.scanView)
new("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, UI.scanBody)

UI.dumpToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.dumpView)
UI.dumpScanBtn = mkButton(UI.dumpToolbar, {size=UDim2.fromOffset(130,34), text=tr("scan_scripts"), bg=P.accentTint, textColor=P.accent})
UI.dumpCopyBtn = mkButton(UI.dumpToolbar, {size=UDim2.fromOffset(120,34), position=UDim2.new(0,142,0,0), text=tr("copy_paths")})
UI.dumpFilterBtn = mkButton(UI.dumpToolbar, {size=UDim2.fromOffset(110,34), position=UDim2.new(0,274,0,0), text=tr("all")})
local _dumpSearchWrap, dumpSearchBox = mkInput(UI.dumpToolbar, {
    size=UDim2.new(1,-410,0,34), position=UDim2.new(0,396,0,0), placeholder="Search scripts...",
})
UI.dumpStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,20), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=string.format(tr("scripts_found"),0),
    TextColor3=P.textMuted, Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.dumpView)
UI.dumpList = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-88), Position=UDim2.new(0,24,0,80),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.dumpView)
new("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, UI.dumpList)

UI.decToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.decView)
UI.decAllBtn = mkButton(UI.decToolbar, {size=UDim2.fromOffset(150,34), text=tr("decompile_all"), bg=P.accentTint, textColor=P.accent})
UI.decCopyBtn = mkButton(UI.decToolbar, {size=UDim2.fromOffset(90,34), position=UDim2.new(0,162,0,0), text=tr("copy")})
UI.decRunBtn = mkButton(UI.decToolbar, {size=UDim2.fromOffset(110,34), position=UDim2.new(0,264,0,0), text=tr("run_code")})
UI.decStatus = new("TextLabel", {
    Size=UDim2.new(1,-410,1,0), Position=UDim2.new(0,386,0,0),
    BackgroundTransparency=1, Text=tr("ready"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,
}, UI.decToolbar)
UI.decProgress = new("Frame", {
    Size=UDim2.new(1,-48,0,4), Position=UDim2.new(0,24,0,54),
    BackgroundColor3=P.border, BorderSizePixel=0,
}, UI.decView)
corner(UI.decProgress, 2)
UI.decProgressFill = new("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=P.accent, BorderSizePixel=0}, UI.decProgress)
corner(UI.decProgressFill, 2)
UI.decLiveStatus = new("Frame", {
    Size=UDim2.new(1,-48,0,32), Position=UDim2.new(0,24,0,62),
    BackgroundColor3=P.surface2, BorderSizePixel=0, Visible=false, ZIndex=100,
}, UI.decView)
corner(UI.decLiveStatus, 8); stroke(UI.decLiveStatus, P.accent, 1)
UI.decLiveLabel = new("TextLabel", {
    Size=UDim2.new(1,-120,1,0), Position=UDim2.new(0,14,0,0),
    BackgroundTransparency=1, Text="", TextColor3=P.textPrimary,
    Font=EF.GothamMedium, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,
}, UI.decLiveStatus)
UI.decLiveBar = new("Frame", {
    Size=UDim2.new(0,0,0,3), Position=UDim2.new(0,0,1,-3),
    BackgroundColor3=P.accent, BorderSizePixel=0,
}, UI.decLiveStatus)
corner(UI.decLiveBar, 2)
UI.decScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-100), Position=UDim2.new(0,24,0,100),
    BackgroundColor3=P.codeBg, BorderSizePixel=0, ScrollBarThickness=6,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.XY,
}, UI.decView)
corner(UI.decScroll, 10); stroke(UI.decScroll, P.border, 1)
UI.decCode = new("TextBox", {
    Size=UDim2.new(1,0,0,0), BackgroundTransparency=1,
    Text=tr("dec_placeholder"), TextColor3=P.codeText, Font=EF.Code,
    TextSize=12, TextWrapped=false, MultiLine=true, TextEditable=false,
    ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, AutomaticSize=Enum.AutomaticSize.XY,
}, UI.decScroll)
pad(UI.decCode, 16, 16, 18, 18)

UI.spyToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.spyView)
UI.spyToggle = mkButton(UI.spyToolbar, {size=UDim2.fromOffset(100,34), text=tr("start"), bg=P.accentTint, textColor=P.accent})
UI.spyClearBtn = mkButton(UI.spyToolbar, {size=UDim2.fromOffset(90,34), position=UDim2.new(0,112,0,0), text=tr("clear")})
UI.spyCopyBtn = mkButton(UI.spyToolbar, {size=UDim2.fromOffset(90,34), position=UDim2.new(0,214,0,0), text=tr("copy")})
UI.spySendBtn = mkButton(UI.spyToolbar, {size=UDim2.fromOffset(100,34), position=UDim2.new(0,316,0,0), text=tr("send_ai")})
local _spySearchWrap, spySearchBox = mkInput(UI.spyToolbar, {
    size=UDim2.new(1,-440,0,34), position=UDim2.new(0,428,0,0), placeholder="Filter...",
})
UI.spyStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,20), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=string.format(tr("spy_calls"),0),
    TextColor3=P.textMuted, Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.spyView)
UI.spyList = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-88), Position=UDim2.new(0,24,0,80),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.spyView)
new("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, UI.spyList)

UI.patternsToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.patternsView)
UI.patternsRunBtn = mkButton(UI.patternsToolbar, {size=UDim2.fromOffset(150,34), text=tr("run_detection"), bg=P.accentTint, textColor=P.accent})
UI.patternsStatus = new("TextLabel", {
    Size=UDim2.new(1,-220,1,0), Position=UDim2.new(0,170,0,0),
    BackgroundTransparency=1, Text=tr("ready"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.patternsToolbar)
UI.patternsList = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-68), Position=UDim2.new(0,24,0,60),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.patternsView)
new("UIListLayout", {Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder}, UI.patternsList)

UI.searchToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.searchView)
local _searchWrap, searchBox = mkInput(UI.searchToolbar, {
    size=UDim2.new(1,-180,0,34), position=UDim2.new(0,0,0,0),
    placeholder="Search in scripts...",
})
UI.searchRunBtn = mkButton(UI.searchToolbar, {
    size=UDim2.fromOffset(140,34), position=UDim2.new(1,-140,0,0),
    text=tr("search"), bg=P.accentTint, textColor=P.accent,
})
UI.searchStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,20), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=tr("search_hint"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.searchView)
UI.searchList = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-88), Position=UDim2.new(0,24,0,80),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.searchView)
new("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, UI.searchList)

UI.worldToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.worldView)
UI.worldRefreshBtn = mkButton(UI.worldToolbar, {size=UDim2.fromOffset(110,34), text=tr("refresh"), bg=P.accentTint, textColor=P.accent})
local _worldFilterWrap, worldFilterBox = mkInput(UI.worldToolbar, {
    size=UDim2.new(1,-130,0,34), position=UDim2.new(0,122,0,0), placeholder="Filter objects...",
})
UI.worldStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,18), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=tr("ready"), TextColor3=P.textMuted,
    Font=EF.Gotham, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.worldView)
UI.worldSplit = new("Frame", {Size=UDim2.new(1,-48,1,-84), Position=UDim2.new(0,24,0,76), BackgroundTransparency=1}, UI.worldView)
UI.worldList = new("ScrollingFrame", {
    Size=UDim2.new(0.4,-8,1,0), BackgroundColor3=P.surface1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.worldSplit)
corner(UI.worldList, 10); stroke(UI.worldList, P.border, 1); pad(UI.worldList, 10, 10, 10, 10)
new("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, UI.worldList)
UI.worldDetail = new("Frame", {
    Size=UDim2.new(0.6,-8,1,0), Position=UDim2.new(0.4,8,0,0),
    BackgroundColor3=P.surface1, BorderSizePixel=0,
}, UI.worldSplit)
corner(UI.worldDetail, 10); stroke(UI.worldDetail, P.border, 1); pad(UI.worldDetail, 18, 18, 18, 18)
UI.worldDetailTitle = new("TextLabel", {
    Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, Text=tr("select_object"),
    TextColor3=P.textPrimary, Font=EF.GothamBold, TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left,
}, UI.worldDetail)
UI.worldDetailBody = new("TextLabel", {
    Size=UDim2.new(1,0,1,-34), Position=UDim2.new(0,0,0,32),
    BackgroundTransparency=1, Text="", TextColor3=P.textSecondary,
    Font=EF.Code, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
}, UI.worldDetail)

local function mkTestScroll(parent)
    local sf = new("ScrollingFrame", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=4, ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
    }, parent)
    pad(sf, 24, 24, 24, 24)
    new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, sf)
    return sf
end
local function mkTestCard(parent, order, title, desc)
    local card = mkCard(parent, {size=UDim2.new(1,0,0,112), layoutOrder=order})
    new("TextLabel", {
        Size=UDim2.new(1,-180,0,20), Position=UDim2.new(0,20,0,12),
        BackgroundTransparency=1, Text=title, TextColor3=P.textPrimary,
        Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
    }, card)
    new("TextLabel", {
        Size=UDim2.new(1,-180,0,32), Position=UDim2.new(0,20,0,36),
        BackgroundTransparency=1, Text=desc, TextColor3=P.textMuted,
        Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true, TextYAlignment=Enum.TextYAlignment.Top,
    }, card)
    local status = new("TextLabel", {
        Size=UDim2.new(1,-20,0,16), Position=UDim2.new(0,20,1,-26),
        BackgroundTransparency=1, Text=tr("ready"), TextColor3=P.textMuted,
        Font=EF.Code, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
    }, card)
    local runBtn = mkButton(card, {
        size=UDim2.fromOffset(75,30), position=UDim2.new(1,-90,0,14),
        text=tr("run_code"), bg=P.accentTint, textColor=P.accent,
    })
    local stopBtn = mkButton(card, {
        size=UDim2.fromOffset(75,30), position=UDim2.new(1,-90,1,-46),
        text=tr("stop"), bg=P.dangerTint, textColor=P.danger,
    })
    return card, runBtn, stopBtn, status
end

UI.resScroll = mkTestScroll(UI.resView)
UI.resCards = {}
UI.resCards.snap = {mkTestCard(UI.resScroll, 1, "Snapshot Player Stats", "Reads all ValueBase of Player.")}
UI.resCards.compare = {mkTestCard(UI.resScroll, 2, "Compare Against Snapshot", "Compares stats vs last snapshot.")}
UI.resCards.dup = {mkTestCard(UI.resScroll, 3, "Duplicate-Call Detector", "Flags identical remote call signatures.")}

UI.protScroll = mkTestScroll(UI.protView)
UI.protCards = {}
UI.protCards.owner = {mkTestCard(UI.protScroll, 1, "Ownership Scan", "Enumerates Owner/OwnerId attributes.")}
UI.protCards.access = {mkTestCard(UI.protScroll, 2, "Restricted Access Scan", "Scans Locked/Owned/Private attrs.")}
UI.protCards.revert = {mkTestCard(UI.protScroll, 3, "Local Modification Revert", "Tests server revert behavior.")}

UI.snapToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.snapshotsView)
UI.snapSaveBtn = mkButton(UI.snapToolbar, {size=UDim2.fromOffset(150,34), text=tr("save_current"), bg=P.accentTint, textColor=P.accent})
UI.snapRefreshBtn = mkButton(UI.snapToolbar, {size=UDim2.fromOffset(120,34), position=UDim2.new(0,162,0,0), text=tr("refresh_list")})
UI.snapStatus = new("TextLabel", {
    Size=UDim2.new(1,-48,0,20), Position=UDim2.new(0,24,0,54),
    BackgroundTransparency=1, Text=string.format(tr("snapshots_count"),0),
    TextColor3=P.textMuted, Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.snapshotsView)
UI.snapList = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-88), Position=UDim2.new(0,24,0,80),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.snapshotsView)
new("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, UI.snapList)

UI.logsToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.logsView)
UI.logsClearBtn = mkButton(UI.logsToolbar, {size=UDim2.fromOffset(100,34), text=tr("clear"), bg=P.dangerTint, textColor=P.danger})
UI.logsCopyBtn = mkButton(UI.logsToolbar, {size=UDim2.fromOffset(100,34), position=UDim2.new(0,112,0,0), text=tr("copy_all")})
UI.logsFilterBtn = mkButton(UI.logsToolbar, {size=UDim2.fromOffset(100,34), position=UDim2.new(0,224,0,0), text="ALL"})
UI.logsBody = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-68), Position=UDim2.new(0,24,0,60),
    BackgroundColor3=P.surface1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.logsView)
corner(UI.logsBody, 10); stroke(UI.logsBody, P.border, 1); pad(UI.logsBody, 10, 10, 10, 10)
new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder}, UI.logsBody)

local logsFilter = "ALL"
S.renderLogs = function()
    if S.unloaded or not UI.logsBody then return end
    clearGuiChildren(UI.logsBody)
    local shown = 0
    for i=#S.logs,1,-1 do
        local e = S.logs[i]
        if logsFilter == "ALL" or e.level == logsFilter then
            shown = shown + 1
            if shown > 300 then break end
            new("TextLabel", {
                Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
                Text=("[%s] [%s] [%s] %s"):format(e.ts, e.level, e.src, e.msg),
                TextColor3=LOG_COLORS[e.level] or P.textPrimary,
                Font=EF.Code, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
                TextTruncate=Enum.TextTruncate.AtEnd, LayoutOrder=-i,
            }, UI.logsBody)
        end
    end
end
local logsRenderQueued = false
S.onLog = function()
    if S.currentView ~= "logs" then return end
    if logsRenderQueued then return end
    logsRenderQueued = true
    task.delay(0.2, function()
        logsRenderQueued = false
        if not S.unloaded and S.currentView == "logs" then pcall(S.renderLogs) end
    end)
end
UI.logsClearBtn.MouseButton1Click:Connect(function()
    S.logs = {}; S.renderLogs(); S.showToast(tr("logs_cleared"))
end)
UI.logsCopyBtn.MouseButton1Click:Connect(function()
    local lines = {}
    for _,e in ipairs(S.logs) do
        lines[#lines+1] = ("[%s] [%s] [%s] %s"):format(e.ts, e.level, e.src, e.msg)
    end
    local clip = clipFn()
    if clip then
        pcall(clip, table.concat(lines, "\n"))
        S.showToast(string.format(tr("lines_copied"), #lines), "success")
    end
end)
UI.logsFilterBtn.MouseButton1Click:Connect(function()
    local opts = {"ALL","INFO","WARN","ERROR","SUCCESS","TEST"}
    local idx = 1
    for i,v in ipairs(opts) do if v == logsFilter then idx = i end end
    idx = idx % #opts + 1
    logsFilter = opts[idx]
    UI.logsFilterBtn.Text = logsFilter
    S.renderLogs()
end)

UI.safeScroll = mkTestScroll(UI.safeView)
UI.safeInfoCard = mkCard(UI.safeScroll, {size=UDim2.new(1,0,0,220), layoutOrder=1})
new("TextLabel", {
    Size=UDim2.new(1,-36,0,20), Position=UDim2.new(0,20,0,14),
    BackgroundTransparency=1, Text="ACTIVE RESOURCES", TextColor3=P.accent,
    Font=EF.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, UI.safeInfoCard)
UI.safeInfo = new("TextLabel", {
    Size=UDim2.new(1,-36,1,-48), Position=UDim2.new(0,20,0,42),
    BackgroundTransparency=1, Text="", TextColor3=P.textPrimary,
    Font=EF.Code, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
}, UI.safeInfoCard)
UI.safeStopBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text=tr("stop_all_tasks"),
    bg=P.dangerTint, textColor=P.danger, textSize=13, layoutOrder=2,
})
UI.safeRevertBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text="Revert local (WalkSpeed / JumpPower)", layoutOrder=3,
})
UI.safeClearCacheBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text="Clear decompile cache", layoutOrder=4,
})
UI.safePurgeKBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text="Purge knowledge base", layoutOrder=5,
})
UI.safeHideBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text="Hide window", layoutOrder=6,
})
UI.safeUnloadBtn = mkButton(UI.safeScroll, {
    size=UDim2.new(1,0,0,44), text=tr("unload"),
    bg=P.dangerTint, textColor=P.danger, textSize=13, layoutOrder=7,
})

UI.memoryToolbar = new("Frame", {Size=UDim2.new(1,-48,0,40), Position=UDim2.new(0,24,0,8), BackgroundTransparency=1}, UI.memoryView)
UI.memoryAddBtn = mkButton(UI.memoryToolbar, {
    size=UDim2.fromOffset(150,34), text=tr("memory_add"), bg=P.accentTint, textColor=P.accent,
})
UI.memoryClearBtn = mkButton(UI.memoryToolbar, {
    size=UDim2.fromOffset(150,34), position=UDim2.new(0,160,0,0),
    text=tr("memory_clear"), bg=P.dangerTint, textColor=P.danger,
})
UI.memoryStatus = new("TextLabel", {
    Size=UDim2.new(1,-320,0,20), Position=UDim2.new(0,320,0,7),
    BackgroundTransparency=1, Text=string.format(tr("memory_entries"),0),
    TextColor3=P.textMuted, Font=EF.Gotham, TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
}, UI.memoryToolbar)
UI.memoryScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-48,1,-68), Position=UDim2.new(0,24,0,60),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.memoryView)
new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, UI.memoryScroll)
S.renderMemory = function()
    if S.unloaded or not UI.memoryScroll then return end
    clearGuiChildren(UI.memoryScroll)
    local total = 0
    for _,cat in pairs(S.aiMemory) do for _ in pairs(cat) do total=total+1 end end
    UI.memoryStatus.Text = string.format(tr("memory_entries"), total)
    if total == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,60), BackgroundTransparency=1,
            Text="No memory entries yet.",
            TextColor3=P.textMuted, Font=EF.Gotham, TextSize=12, TextWrapped=true, LayoutOrder=0,
        }, UI.memoryScroll)
        return
    end
    local order = 0
    for category,entries in pairs(S.aiMemory) do
        order = order + 1
        new("TextLabel", {
            Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
            Text="["..category:upper().."]", TextColor3=P.accent,
            Font=EF.GothamBold, TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=order,
        }, UI.memoryScroll)
        for key,entry in pairs(entries) do
            order = order + 1
            local card = mkCard(UI.memoryScroll, {size=UDim2.new(1,0,0,50), layoutOrder=order})
            new("TextLabel", {
                Size=UDim2.new(1,-100,0,16), Position=UDim2.new(0,14,0,8),
                BackgroundTransparency=1, Text=key, TextColor3=P.textPrimary,
                Font=EF.GothamBold, TextSize=12,
                TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
            }, card)
            new("TextLabel", {
                Size=UDim2.new(1,-100,0,14), Position=UDim2.new(0,14,0,26),
                BackgroundTransparency=1, Text=tostring(entry.value),
                TextColor3=P.textSecondary, Font=EF.Gotham, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
            }, card)
            new("TextLabel", {
                Size=UDim2.new(0,90,0,14), Position=UDim2.new(1,-100,0,8),
                BackgroundTransparency=1, Text="x"..tostring(entry.count or 1),
                TextColor3=P.textMuted, Font=EF.Gotham, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Right,
            }, card)
        end
    end
end
UI.memoryAddBtn.MouseButton1Click:Connect(function()
    local key = "user_note_"..os.time()
    aiMemoryAdd("custom", key, "Manual memory entry")
    S.showToast(string.format(tr("memory_learned"), key), "success")
    if S.renderMemory then S.renderMemory() end
end)
UI.memoryClearBtn.MouseButton1Click:Connect(function()
    S.aiMemory = {}
    saveAiMemory()
    S.showToast(tr("memory_forgotten"), "success")
    if S.renderMemory then S.renderMemory() end
end)

UI.marketScroll = new("ScrollingFrame", {
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=P.border,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.marketView)
pad(UI.marketScroll, 24, 24, 24, 24)
new("UIListLayout", {Padding=UDim.new(0,12), SortOrder=Enum.SortOrder.LayoutOrder}, UI.marketScroll)
S.renderMarketplace = function()
    if S.unloaded or not UI.marketScroll then return end
    clearGuiChildren(UI.marketScroll)
    local order = 0
    for _,script in ipairs(S.marketplaceScripts) do
        order = order + 1
        local isInstalled = S.marketplaceInstalled[script.id] ~= nil
        local card = mkCard(UI.marketScroll, {size=UDim2.new(1,0,0,80), layoutOrder=order})
        new("TextLabel", {
            Size=UDim2.new(1,-200,0,20), Position=UDim2.new(0,14,0,10),
            BackgroundTransparency=1, Text=script.name, TextColor3=P.textPrimary,
            Font=EF.GothamBold, TextSize=13,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, card)
        new("TextLabel", {
            Size=UDim2.new(1,-200,0,16), Position=UDim2.new(0,14,0,32),
            BackgroundTransparency=1, Text=script.desc, TextColor3=P.textSecondary,
            Font=EF.Gotham, TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, card)
        new("TextLabel", {
            Size=UDim2.new(0,100,0,14), Position=UDim2.new(1,-200,0,10),
            BackgroundTransparency=1, Text="v"..script.version,
            TextColor3=P.textMuted, Font=EF.Gotham, TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Right,
        }, card)
        new("TextLabel", {
            Size=UDim2.new(0,100,0,14), Position=UDim2.new(1,-200,0,26),
            BackgroundTransparency=1, Text="star "..tostring(script.rating or "?"),
            TextColor3=P.warn, Font=EF.GothamBold, TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Right,
        }, card)
        local actionBtn = mkButton(card, {
            size=UDim2.fromOffset(100,30), position=UDim2.new(1,-110,0.5,-15),
            text=isInstalled and "Installed" or tr("market_install"),
            bg=isInstalled and P.successTint or P.accentTint,
            textColor=isInstalled and P.success or P.accent,
            textSize=11,
        })
        if not isInstalled then
            actionBtn.MouseButton1Click:Connect(function()
                if installMarketplaceScript(script.id) then
                    if S.renderMarketplace then S.renderMarketplace() end
                end
            end)
        end
    end
    if #S.marketplaceScripts == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,60), BackgroundTransparency=1,
            Text=tr("market_no_scripts"), TextColor3=P.textMuted,
            Font=EF.Gotham, TextSize=12, TextWrapped=true,
        }, UI.marketScroll)
    end
end

UI.debugScroll = new("ScrollingFrame", {
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=P.border,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.debugView)
pad(UI.debugScroll, 24, 24, 24, 24)
new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, UI.debugScroll)
S.renderDebugger = function()
    if S.unloaded or not UI.debugScroll then return end
    clearGuiChildren(UI.debugScroll)
    local order = 0
    order = order + 1
    local statusCard = mkCard(UI.debugScroll, {size=UDim2.new(1,0,0,60), layoutOrder=order})
    new("TextLabel", {
        Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,14,0,10),
        BackgroundTransparency=1, Text="Debugger Status",
        TextColor3=P.textPrimary, Font=EF.GothamBold, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, statusCard)
    new("TextLabel", {
        Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,14,0,32),
        BackgroundTransparency=1,
        Text=S.debuggerActive and tr("debug_running") or tr("ready"),
        TextColor3=S.debuggerActive and P.success or P.textMuted,
        Font=EF.Gotham, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, statusCard)
    order = order + 1
    local bpCard = mkCard(UI.debugScroll, {size=UDim2.new(1,0,0,100), layoutOrder=order})
    local bpCount = 0
    for _ in pairs(S.debuggerBreakpoints) do bpCount = bpCount + 1 end
    new("TextLabel", {
        Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,14,0,10),
        BackgroundTransparency=1, Text="Breakpoints ("..bpCount..")",
        TextColor3=P.textPrimary, Font=EF.GothamBold, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, bpCard)
    local bpList = ""
    for _,bp in pairs(S.debuggerBreakpoints) do
        bpList = bpList.."  Line "..tostring(bp.line).." ["..(bp.enabled and "ON" or "OFF").."]\n"
    end
    new("TextLabel", {
        Size=UDim2.new(1,-20,0,60), Position=UDim2.new(0,14,0,32),
        BackgroundTransparency=1, Text=bpList ~= "" and bpList or "No breakpoints",
        TextColor3=P.textSecondary, Font=EF.Code, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,
    }, bpCard)
    order = order + 1
    local logCard = mkCard(UI.debugScroll, {size=UDim2.new(1,0,0,240), layoutOrder=order})
    new("TextLabel", {
        Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,14,0,10),
        BackgroundTransparency=1, Text="Debug Log ("..#S.debuggerLog..")",
        TextColor3=P.textPrimary, Font=EF.GothamBold, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, logCard)
    local logText = ""
    for i=math.max(1,#S.debuggerLog-20),#S.debuggerLog do
        local entry = S.debuggerLog[i]
        logText = logText.."["..tostring(entry.level).."] "..tostring(entry.msg).."\n"
    end
    new("TextLabel", {
        Size=UDim2.new(1,-20,1,-40), Position=UDim2.new(0,14,0,32),
        BackgroundTransparency=1, Text=logText ~= "" and logText or "No log entries",
        TextColor3=P.textSecondary, Font=EF.Code, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,
    }, logCard)
end

local function getLuaPath(inst)
    local chain = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(chain, 1, cur)
        cur = cur.Parent
    end
    if #chain == 0 then return nil end
    local s
    if cur == game then
        s = 'game:GetService("'..chain[1].ClassName..'")'
        for i=2,#chain do
            local n = chain[i].Name
            if chain[i] == player then s = s..".LocalPlayer"
            elseif n:match("^[%a_][%w_]*$") then s = s.."."..n
            else s = s..'["'..n:gsub("\\","\\\\"):gsub('"','\\"')..'"]' end
        end
    else
        s = chain[1].Name
        for i=2,#chain do
            local n = chain[i].Name
            if n:match("^[%a_][%w_]*$") then s = s.."."..n
            else s = s..'["'..n:gsub("\\","\\\\"):gsub('"','\\"')..'"]' end
        end
        s = s.." (unreplicated-parent)"
    end
    return s
end
local function classifyDecompile(code)
    if type(code) ~= "string" then return "fail", "nil" end
    if #code < 8 then return "fail", "too_short" end
    local lower = code:lower()
    for _,pat in ipairs({"decompilation failed","failed to decompile","could not decompile","unsupported bytecode","not decompilable","error decompiling"}) do
        if lower:find(pat,1,true) then return "fail", "error_pattern" end
    end
    local codeLines = 0
    for line in code:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        if trimmed ~= "" and not trimmed:match("^%-%-") then codeLines = codeLines + 1 end
    end
    if codeLines < 2 then return "fail", "comments_only" end
    if #code < 40 then return "partial", "very_short" end
    return "ok", "success"
end

local CACHE_DIR = CFG.dir.."/cache"
ensureDir(CACHE_DIR)
local memoryCacheOrder = {}
local function safeCacheName(path) return (path:gsub("[^%w_%-]","_")) end
local function cacheAdd(inst, code)
    if not code or #code < 5 then return end
    S.cache[inst] = code
    for i,ref in ipairs(memoryCacheOrder) do
        if ref == inst then table.remove(memoryCacheOrder, i); break end
    end
    table.insert(memoryCacheOrder, inst)
    while #memoryCacheOrder > DECO.memoryCacheMax do
        local old = table.remove(memoryCacheOrder, 1)
        if old then S.cache[old] = nil end
    end
end
local function cacheGet(inst)
    if S.cache[inst] then
        for i,ref in ipairs(memoryCacheOrder) do
            if ref == inst then
                table.remove(memoryCacheOrder, i)
                table.insert(memoryCacheOrder, inst)
                break
            end
        end
        return S.cache[inst]
    end
    return nil
end
local function saveToDisk(path, code)
    if not hasFS() then return false end
    local fname = CACHE_DIR.."/"..safeCacheName(path)..".lua"
    return safeWrite(fname, code)
end
local function loadFromDisk(path)
    if not hasFS() then return nil end
    local fname = CACHE_DIR.."/"..safeCacheName(path)..".lua"
    return safeRead(fname)
end
local CODE_KEEP = 12000
getScriptCode = function(e)
    if not e then return nil end
    if type(e.code)=="string" and #e.code > 0 then return e.code end
    if e.inst then
        local mem = cacheGet(e.inst)
        if mem then e.code = mem; return mem end
    end
    if hasFS() and e.path then
        local disk = loadFromDisk(e.path)
        if disk and #disk > 0 then
            e.code = (#disk > CODE_KEEP) and cut(disk, CODE_KEEP) or disk
            return disk
        end
    end
    return nil
end
local function storeScriptCode(e, code)
    if not e or type(code) ~= "string" then return end
    e.code = (#code > CODE_KEEP) and cut(code, CODE_KEEP) or code
    e.codeCached = true
end

local SCAN_SERVICES = {"ReplicatedStorage","ReplicatedFirst","StarterGui","StarterPlayer","StarterPack","Players","Workspace","Lighting","SoundService","TextChatService","Chat"}
local function iterGameTree(onInstance, maxCount, yieldEvery)
    maxCount = maxCount or 150000
    yieldEvery = yieldEvery or 300
    local n = 0
    local selfGui = UI.gui
    local function consider(obj)
        if n >= maxCount or S.unloaded then return false end
        if selfGui and (obj == selfGui or (obj.Parent and obj.Parent.Name == "SonicAI")) then return true end
        n = n + 1
        onInstance(obj)
        if n % yieldEvery == 0 then task.wait() end
        return true
    end
    local function visitRoot(root)
        if not root then return end
        consider(root)
        local ok,desc = pcall(function() return root:GetDescendants() end)
        if not ok or type(desc) ~= "table" then return end
        for i=1,#desc do
            if S.unloaded or n >= maxCount then return end
            consider(desc[i])
        end
    end
    for _,name in ipairs(SCAN_SERVICES) do
        if S.unloaded or n >= maxCount then break end
        local ok,svc = pcall(function() return game:GetService(name) end)
        if ok and svc then visitRoot(svc) end
    end
    return n
end

local scanRunning = false
S.scanGame = function()
    if scanRunning then S.showToast(tr("scan_already_running"), "warn"); return end
    scanRunning = true
    UI.scanStatus.Text = tr("scanning")
    UI.scanRunBtn.Text = tr("scan_btn_busy")
    trackTask(task.spawn(function()
        local remotes, scripts, buttons, attrs = {}, {}, {}, {}
        local scanned = iterGameTree(function(obj)
            local cn = obj.ClassName
            if cn == "RemoteEvent" or cn == "RemoteFunction" then
                if #remotes < 300 then remotes[#remotes+1] = obj:GetFullName() end
            elseif cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
                if #scripts < 300 then scripts[#scripts+1] = obj:GetFullName() end
            elseif cn == "TextButton" or cn == "ImageButton" then
                if #buttons < 80 then buttons[#buttons+1] = obj:GetFullName() end
            end
            if #attrs < 80 then
                local ok,a = pcall(function() return obj:GetAttributes() end)
                if ok and a then
                    for k,v in pairs(a) do
                        local tv = type(v)
                        if tv == "number" or tv == "string" or tv == "boolean" then
                            attrs[#attrs+1] = obj.Name.."."..k.." = "..tostring(v)
                            if #attrs >= 80 then break end
                        end
                    end
                end
            end
        end, 150000, 300)
        if S.unloaded then scanRunning = false; return end
        S.log("INFO", "scanner", "Scanned "..tostring(scanned).." instances")
        clearGuiChildren(UI.scanBody)
        local ord = 0
        local function section(t, list)
            ord = ord + 1
            new("TextLabel", {
                Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Text=t,
                TextColor3=P.accent, Font=EF.GothamBold, TextSize=12,
                TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=ord,
            }, UI.scanBody)
            for _,l in ipairs(list) do
                ord = ord + 1
                new("TextLabel", {
                    Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=l,
                    TextColor3=P.textPrimary, Font=EF.Code, TextSize=10,
                    TextXAlignment=Enum.TextXAlignment.Left,
                    TextTruncate=Enum.TextTruncate.AtEnd, LayoutOrder=ord,
                }, UI.scanBody)
            end
        end
        section("REMOTES ("..#remotes..")", remotes)
        section("SCRIPTS ("..#scripts..")", scripts)
        section("BUTTONS ("..#buttons..")", buttons)
        section("ATTRIBUTES ("..#attrs..")", attrs)
        S.scannerReport = "GAME CONTEXT\nPlace: "..tostring(game.PlaceId).."\nRemotes: "..#remotes.."\nScripts: "..#scripts..
            "\nREMOTES:\n"..table.concat(remotes, "\n").."\nSCRIPTS:\n"..table.concat(scripts, "\n")
        S.scanner = {remotes=remotes, scripts=scripts, buttons=buttons, attrs=attrs}
        for _,rp in ipairs(remotes) do
            local r = resolveByFullName(rp)
            if r then S.kbAddRemote(rp, r.Name, "discovered", "") end
        end
        UI.scanStatus.Text = string.format(tr("scan_status"), #remotes, #scripts)
        UI.scanRunBtn.Text = tr("scan_game")
        scanRunning = false
        S.log("SUCCESS", "scanner", "Scan complete")
        S.showToast(tr("scan_complete"), "success")
        S.updateDash()
    end))
end
UI.scanRunBtn.MouseButton1Click:Connect(function() S.scanGame() end)
UI.scanCopyBtn.MouseButton1Click:Connect(function()
    if S.scannerReport == "" then return end
    local clip = clipFn()
    if clip then pcall(clip, S.scannerReport); S.showToast(tr("report_copied"), "success") end
end)
UI.scanSaveBtn.MouseButton1Click:Connect(function()
    if S.scannerReport == "" then return end
    if not hasFS() then S.showToast(tr("no_filesystem"), "error"); return end
    ensureDir(CFG.dir)
    local fname = CFG.dir.."/scan_"..os.time()..".txt"
    local ok = safeWrite(fname, S.scannerReport)
    S.showToast(ok and string.format(tr("saved"), fname) or tr("save_failed"), ok and "success" or "error")
end)

local dumpFilter = "all"
local dumpSearchQ = ""
local function mkDumpItem(e, i)
    local item = new("Frame", {
        Size=UDim2.new(1,0,0,46), BackgroundColor3=P.surface1,
        BorderSizePixel=0, LayoutOrder=i,
    }, UI.dumpList)
    corner(item, 8); stroke(item, P.border, 1)
    new("TextLabel", {
        Size=UDim2.new(1,-280,0,16), Position=UDim2.new(0,14,0,6),
        BackgroundTransparency=1, Text=e.name.." ["..e.class.."]",
        TextColor3=P.textPrimary, Font=EF.GothamMedium, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
    }, item)
    new("TextLabel", {
        Size=UDim2.new(1,-280,0,14), Position=UDim2.new(0,14,0,24),
        BackgroundTransparency=1, Text=cut(e.path,90), TextColor3=P.textMuted,
        Font=EF.Code, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
    }, item)
    local st = e.status or "pending"
    local stColor, stText, stBg
    if st == "ok" then stColor, stText, stBg = P.success, "OK", P.successTint
    elseif st == "partial" then stColor, stText, stBg = P.partial, "PARTIAL", P.partialTint
    elseif st == "fail" then stColor, stText, stBg = P.danger, "FAIL", P.dangerTint
    elseif st == "decoding" then stColor, stText, stBg = P.accent, "...", P.accentTint
    else stColor, stText, stBg = P.textMuted, "PENDING", P.surface3 end
    mkBadge(item, {
        size=UDim2.fromOffset(64,20), position=UDim2.new(1,-278,0,13),
        text=stText, bg=stBg, textColor=stColor,
    })
    local cpBtn = mkButton(item, {size=UDim2.fromOffset(60,24), position=UDim2.new(1,-210,0.5,-12), text=tr("copy"), textSize=10})
    cpBtn.MouseButton1Click:Connect(function()
        local clip = clipFn()
        if clip then pcall(clip, e.path); S.showToast(tr("path_copied"), "success") end
    end)
    local viewBtn = mkButton(item, {size=UDim2.fromOffset(60,24), position=UDim2.new(1,-144,0.5,-12), text=tr("view_full"), textSize=10})
    viewBtn.MouseButton1Click:Connect(function()
        local code = getScriptCode(e)
        S.openScriptViewer(e.name.." - "..cut(e.path,60),
            code or ("-- Not decompiled yet\n-- Path: "..e.path.."\n-- Status: "..tostring(e.status)))
    end)
    local decBtn = mkButton(item, {
        size=UDim2.new(0,60,0,24), position=UDim2.new(1,-78,0.5,-12),
        text="DEC", textSize=10, bg=P.accentTint, textColor=P.accent,
    })
    decBtn.MouseButton1Click:Connect(function()
        if e.status == "decoding" then return end
        local cached = cacheGet(e.inst)
        if cached then
            UI.decCode.Text = cached; S.switchView("dec")
            S.showToast(tr("loaded_from_memory"), "success"); return
        end
        if hasFS() then
            local disk = loadFromDisk(e.path)
            if disk and #disk > 10 then
                cacheAdd(e.inst, disk); UI.decCode.Text = disk; e.code = disk
                e.status = classifyDecompile(disk)
                S.switchView("dec"); S.showToast(tr("loaded_from_disk"), "success")
                S.renderDump(); return
            end
        end
        e.status = "decoding"; S.renderDump()
        UI.decLiveLabel.Text = "Decompiling: "..cut(e.name,50)
        UI.decLiveStatus.Visible = true
        trackTask(task.spawn(function()
            if not e.inst or not e.inst.Parent then
                e.status = "fail"; e.failReason = "instance_destroyed"
                UI.decLiveStatus.Visible = false
                S.sessionFail = S.sessionFail + 1
                S.renderDump(); S.updateDash(); return
            end
            local ok,code = pcall(decompile, e.inst)
            UI.decLiveStatus.Visible = false
            if S.unloaded then return end
            if ok and type(code)=="string" and #code >= 5 then
                local st2, sub = classifyDecompile(code)
                e.status = st2; e.failReason = sub
                if st2 == "ok" then S.sessionOk = S.sessionOk + 1
                elseif st2 == "partial" then S.sessionPartial = S.sessionPartial + 1
                else S.sessionFail = S.sessionFail + 1 end
                if st2 ~= "fail" then
                    storeScriptCode(e, code)
                    if hasFS() then saveToDisk(e.path, code) end
                    cacheAdd(e.inst, code)
                    S.kbAddScript({path=e.path, name=e.name, class=e.class, code=code})
                end
                UI.decCode.Text = code; S.switchView("dec")
                S.showToast(string.format(tr("decompiled_status"), st2), "success")
            else
                e.status = "fail"; e.failReason = "pcall_error"
                S.sessionFail = S.sessionFail + 1
                S.showToast(tr("failed"), "error")
            end
            S.renderDump(); S.updateDash()
        end))
    end)
    return item
end

S.renderDump = function()
    if S.unloaded or not UI.dumpList then S._dumpRendering = false; return end
    if S._dumpRendering then return end
    S._dumpRendering = true
    clearGuiChildren(UI.dumpList)
    local ok_n, ptl_n, fail_n = 0, 0, 0
    for _,e in ipairs(S.dumped) do
        local st = e.status or "pending"
        if st == "ok" then ok_n = ok_n + 1
        elseif st == "partial" then ptl_n = ptl_n + 1
        elseif st == "fail" then fail_n = fail_n + 1 end
    end
    local shown = 0
    local q = dumpSearchQ:lower()
    if #S.dumped == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,48), BackgroundTransparency=1,
            Text=tr("no_scripts_yet"), TextColor3=P.textMuted,
            Font=EF.Gotham, TextSize=13, TextWrapped=true,
        }, UI.dumpList)
        UI.dumpStatus.Text = ("Total: 0/%d"):format(CFG.maxDumpScripts)
        S._dumpRendering = false; return
    end
    for i,e in ipairs(S.dumped) do
        if shown >= 100 then break end
        local matches = (dumpFilter == "all" or e.class == dumpFilter)
        if matches and q ~= "" then
            local nm = e.name:lower():find(q,1,true)
            local pm = e.path:lower():find(q,1,true)
            if not (nm or pm) then matches = false end
        end
        if matches then shown = shown + 1; mkDumpItem(e, i) end
    end
    if shown == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,40), BackgroundTransparency=1,
            Text=tr("no_scripts_match"), TextColor3=P.textMuted,
            Font=EF.Gotham, TextSize=12,
        }, UI.dumpList)
    end
    UI.dumpStatus.Text = ("Total: %d/%d - OK:%d - Fail:%d - Shown:%d"):format(
        #S.dumped, CFG.maxDumpScripts, ok_n+ptl_n, fail_n, shown)
    S._dumpRendering = false
end

local dumpScanning = false
S.scanScripts = function()
    if dumpScanning then S.showToast(tr("scan_already_running"), "warn"); return end
    dumpScanning = true
    UI.dumpStatus.Text = tr("scanning")
    UI.dumpScanBtn.Text = "..."
    trackTask(task.spawn(function()
        local list, seen = {}, {}
        local scanned = iterGameTree(function(obj)
            if #list >= CFG.maxDumpScripts then return end
            local cn = obj.ClassName
            if cn ~= "Script" and cn ~= "LocalScript" and cn ~= "ModuleScript" then return end
            local p = getLuaPath(obj)
            if not p or seen[p] then return end
            seen[p] = true
            list[#list+1] = {name=obj.Name, class=cn, path=p, inst=obj, status="pending"}
        end, 200000, 300)
        if S.unloaded then dumpScanning = false; return end
        S.dumped = list
        S.renderDump()
        UI.dumpScanBtn.Text = tr("scan_scripts")
        dumpScanning = false
        S.log("INFO", "dumper", #list.." scripts (scanned "..tostring(scanned)..")")
        S.showToast(string.format(tr("scripts_found"), #list), "success")
        S.updateDash()
    end))
end
UI.dumpScanBtn.MouseButton1Click:Connect(function() S.scanScripts() end)
UI.dumpCopyBtn.MouseButton1Click:Connect(function()
    if #S.dumped == 0 then return end
    local lines = {}
    for _,e in ipairs(S.dumped) do
        lines[#lines+1] = "["..e.class.."] ["..(e.status or "pending").."] "..e.path
    end
    local clip = clipFn()
    if clip then
        pcall(clip, table.concat(lines, "\n"))
        S.showToast(string.format(tr("items_copied"), #S.dumped), "success")
    end
end)
UI.dumpFilterBtn.MouseButton1Click:Connect(function()
    local opts = {"all","Script","LocalScript","ModuleScript"}
    local idx = 1
    for i,v in ipairs(opts) do if v == dumpFilter then idx = i end end
    idx = idx % #opts + 1
    dumpFilter = opts[idx]
    UI.dumpFilterBtn.Text = dumpFilter
    S.renderDump()
end)
local dumpSearchToken = 0
dumpSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    dumpSearchQ = dumpSearchBox.Text
    dumpSearchToken = dumpSearchToken + 1
    local my = dumpSearchToken
    task.delay(0.15, function()
        if my == dumpSearchToken and not S.unloaded then S.renderDump() end
    end)
end)

local decRunning = false
local decCancel = false
S.updateDecStatus = function()
    UI.decStatus.Text = "Cache: "..S.countCache().." (mem)"
end
UI.decAllBtn.MouseButton1Click:Connect(function()
    if decRunning then decCancel = true; S.showToast(tr("cancelling"), "warn"); return end
    if #S.dumped == 0 then S.showToast(tr("scan_scripts_first"), "warn"); return end
    if type(decompile) ~= "function" then S.showToast(tr("decompile_unavailable"), "error"); return end
    local candidates = {}
    for _,e in ipairs(S.dumped) do
        if e.status == "pending" or e.status == "decoding" then candidates[#candidates+1] = e end
    end
    if #candidates == 0 then S.showToast(tr("all_scripts_processed"), "success"); return end
    decRunning = true; decCancel = false
    UI.decAllBtn.Text = tr("stop")
    paintButton(UI.decAllBtn, P.dangerTint, P.danger)
    UI.decLiveStatus.Visible = true
    local maxPerRun = CFG.decMaxPerRun or 500
    local total = math.min(#candidates, maxPerRun)
    local startTime = os.clock()
    trackTask(task.spawn(function()
        local ok_n, ptl_n, fail_n = 0, 0, 0
        for i,e in ipairs(candidates) do
            if S.unloaded or decCancel then break end
            if i > total then break end
            local elapsedSoFar = os.clock() - startTime
            local eta = ""
            if i > 1 and elapsedSoFar > 0 then
                local rate = (i-1)/elapsedSoFar
                if rate > 0 then eta = " - ETA "..fmtTime((total-i+1)/rate) end
            end
            UI.decLiveLabel.Text = ("[%d/%d] %s%s"):format(i, total, cut(e.name,40), eta)
            local code, elapsed = nil, 0
            local cached = cacheGet(e.inst)
            if cached then code = cached
            elseif hasFS() then
                local disk = loadFromDisk(e.path)
                if disk and #disk > 10 then code = disk; cacheAdd(e.inst, disk) end
            end
            if not code then
                if not e.inst or not e.inst.Parent then
                    e.status = "fail"; e.failReason = "instance_destroyed"
                    fail_n = fail_n + 1; S.sessionFail = S.sessionFail + 1
                else
                    if S.unloaded or decCancel then break end
                    local t0 = os.clock()
                    local ok, c = pcall(decompile, e.inst)
                    elapsed = os.clock() - t0
                    if ok and type(c)=="string" and #c >= 5 then code = c
                    else
                        e.status = "fail"; e.failReason = "pcall_error"
                        fail_n = fail_n + 1; S.sessionFail = S.sessionFail + 1
                    end
                end
            end
            if code then
                local st, sub = classifyDecompile(code)
                e.status = st; e.failReason = sub
                if st == "ok" then ok_n = ok_n + 1; S.sessionOk = S.sessionOk + 1
                elseif st == "partial" then ptl_n = ptl_n + 1; S.sessionPartial = S.sessionPartial + 1
                else fail_n = fail_n + 1; S.sessionFail = S.sessionFail + 1 end
                if st ~= "fail" then
                    storeScriptCode(e, code)
                    if hasFS() then saveToDisk(e.path, code) end
                    cacheAdd(e.inst, code)
                    S.kbAddScript({path=e.path, name=e.name, class=e.class, code=code})
                    S._decompiledSinceSave = (S._decompiledSinceSave or 0) + 1
                    if S._decompiledSinceSave >= CFG.autoSaveDecompiled then
                        S._decompiledSinceSave = 0
                        S.saveKB("scripts")
                    end
                end
            end
            local pct = i/total
            UI.decProgressFill.Size = UDim2.new(pct,0,1,0)
            UI.decLiveBar.Size = UDim2.new(pct,0,0,3)
            UI.decStatus.Text = ("%d/%d - OK:%d P:%d F:%d"):format(i,total,ok_n,ptl_n,fail_n)
            if i % DECO.uiUpdateEvery == 0 then S.renderDump() end
            if i < total then
                if elapsed >= 2 then task.wait(0.4)
                elseif elapsed >= 0.5 then task.wait(0.08)
                else task.wait() end
            end
        end
        local dur = os.clock() - startTime
        UI.decProgressFill.Size = UDim2.new(0,0,1,0)
        UI.decLiveBar.Size = UDim2.new(0,0,0,3)
        UI.decLiveStatus.Visible = false
        local avg = total > 0 and (dur/total) or 0
        local msg = ("Done in %.1fs - OK:%d P:%d F:%d - %.3fs/script"):format(dur,ok_n,ptl_n,fail_n,avg)
        UI.decStatus.Text = msg
        UI.decAllBtn.Text = tr("decompile_all")
        paintButton(UI.decAllBtn, P.accentTint, P.accent)
        S.renderDump(); S.updateDash()
        S.log("INFO", "decompiler", msg)
        S.showToast(string.format(tr("done_summary"), ok_n, ptl_n, fail_n), "success")
        decRunning = false; decCancel = false
    end))
end)

local DEC_PLACEHOLDER = "-- Select a script in the Dumper then click DEC"
UI.decCopyBtn.MouseButton1Click:Connect(function()
    local t = UI.decCode.Text
    if t == "" or t == DEC_PLACEHOLDER then S.showToast(tr("nothing_to_copy"), "warn"); return end
    local clip = clipFn()
    if clip then pcall(clip, t); S.showToast(tr("copied"), "success") end
end)
UI.decRunBtn.MouseButton1Click:Connect(function()
    local code = UI.decCode.Text
    if code == "" or code == DEC_PLACEHOLDER then S.showToast(tr("nothing_to_run"), "warn"); return end
    if type(loadstring) ~= "function" then S.showToast(tr("no_loadstring"), "error"); return end
    local fn, err = loadstring(code, "=SAIDec")
    if not fn then S.showToast(string.format(tr("compile_error"), tostring(err)), "error"); return end
    local ok, r = pcall(fn)
    if ok then S.showToast(tr("executed"), "success")
    else S.showToast(string.format(tr("runtime_error"), cut(tostring(r),50)), "error") end
end)

local MAX_LOGS = 300
local function fmtArg(a)
    local t = typeof(a)
    if t == "string" then return '"'..cut(a,20)..'"'
    elseif t == "Instance" then return a:GetFullName()
    elseif t == "number" then return tostring(a)
    else return t end
end
local function logRemote(method, target, args)
    if not S.spyHooked then return end
    if typeof(target) ~= "Instance" then return end
    if #S.remotes >= MAX_LOGS then table.remove(S.remotes) end
    local name = target.Name or "?"
    local argsStr = {}
    for i=1,math.min(#args,4) do argsStr[i] = fmtArg(args[i]) end
    local joinedArgs = table.concat(argsStr, ", ")
    table.insert(S.remotes, 1, {method=method, name=name, path=target:GetFullName(), args=joinedArgs})
    S._spyDirty = true
    S.kbAddRemote(target:GetFullName(), name, method, joinedArgs)
end

S.renderSpy = function()
    if S.unloaded or not UI.spyList then return end
    clearGuiChildren(UI.spyList)
    local q = tostring(S.spyFilter or ""):lower()
    local shown = 0
    for _,l in ipairs(S.remotes) do
        if q == "" or (l.name and l.name:lower():find(q,1,true)) or (l.path and l.path:lower():find(q,1,true)) then
            shown = shown + 1
            if shown > 80 then break end
            new("TextLabel", {
                Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
                Text="["..l.method.."] "..l.name.." ("..l.args..")",
                TextColor3=P.textPrimary, Font=EF.Code, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Left,
                TextTruncate=Enum.TextTruncate.AtEnd, LayoutOrder=shown,
            }, UI.spyList)
        end
    end
    if #S.remotes == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,36), BackgroundTransparency=1,
            Text=S.spyHooked and tr("spy_listening") or tr("spy_start_hint"),
            TextColor3=P.textMuted, Font=EF.Gotham, TextSize=12,
        }, UI.spyList)
    end
    UI.spyStatus.Text = S.spyHooked
        and ("Spy: %d calls - showing %d"):format(#S.remotes, shown)
        or ("Spy stopped - %d stored"):format(#S.remotes)
    S._spyDirty = false
end

S.startSpy = function()
    if S.spyHooked then return end
    if type(hookmetamethod) ~= "function" then S.showToast(tr("hookmetamethod_unavailable"), "error"); return end
    if type(getnamecallmethod) ~= "function" then S.showToast(tr("getnamecall_unavailable"), "error"); return end
    local ok = pcall(function()
        local prevFn
        prevFn = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                pcall(logRemote, m, self, {...})
            end
            return prevFn(self, ...)
        end)
        S.oldNamecall = prevFn
        S.oldSpyOwner = "SonicAI"
    end)
    if ok then
        S.spyHooked = true
        pcall(function()
            if UI.spyToggle then UI.spyToggle.Text = tr("stop") end
            if UI.spyToggle then paintButton(UI.spyToggle, P.dangerTint, P.danger) end
        end)
        S.log("INFO", "spy", "Started")
        if S.renderSpy then S.renderSpy() end
    else
        S.showToast(tr("hook_failed"), "error")
    end
end

S.stopSpy = function()
    if not S.spyHooked then return end
    S.spyHooked = false
    if S.oldNamecall and S.oldSpyOwner == "SonicAI" then
        pcall(function() hookmetamethod(game, "__namecall", S.oldNamecall) end)
    end
    S.oldNamecall = nil; S.oldSpyOwner = nil
    pcall(function()
        if UI.spyToggle then UI.spyToggle.Text = tr("start") end
        if UI.spyToggle then paintButton(UI.spyToggle, P.accentTint, P.accent) end
    end)
    if S.renderSpy then S.renderSpy() end
end

UI.spyToggle.MouseButton1Click:Connect(function()
    if S.spyHooked then S.stopSpy() else S.startSpy() end
end)
UI.spyClearBtn.MouseButton1Click:Connect(function()
    S.remotes = {}; S._spyDirty = true
    S.renderSpy(); S.updateDash()
end)
UI.spyCopyBtn.MouseButton1Click:Connect(function()
    if #S.remotes == 0 then return end
    local seen, lines = {}, {}
    for _,r in ipairs(S.remotes) do
        local k = r.path..":"..r.method
        if not seen[k] then
            seen[k] = true
            lines[#lines+1] = "["..r.method.."] "..r.path.."("..r.args..")"
        end
    end
    local clip = clipFn()
    if clip then pcall(clip, table.concat(lines, "\n")); S.showToast(string.format(tr("items_copied"), #lines), "success") end
end)
UI.spySendBtn.MouseButton1Click:Connect(function()
    if #S.remotes == 0 then return end
    local lines, n = {}, 0
    local seen = {}
    for _,r in ipairs(S.remotes) do
        local k = r.path..":"..r.method
        if not seen[k] then
            seen[k] = true; n = n + 1
            if n > 30 then break end
            lines[#lines+1] = r.path..":"..r.method.."("..r.args..")"
        end
    end
    UI.chatInput.Text = "Remote calls observed:\n"..table.concat(lines, "\n").."\nAnalyze these."
    S.switchView("chat")
end)
local spyFilterToken = 0
spySearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    S.spyFilter = spySearchBox.Text
    spyFilterToken = spyFilterToken + 1
    local my = spyFilterToken
    task.delay(0.12, function()
        if my == spyFilterToken and not S.unloaded then S.renderSpy() end
    end)
end)

local PATTERN_KEYWORDS = {
    autofarm={"farm","collect","gather","harvest","auto_","grind","afk"},
    autosell={"sell","sellall","convert","exchange","cashout","deposit"},
    autobuy={"buy","purchase","shop","acquire","unlock"},
    autoquest={"quest","mission","objective","task","complete"},
    teleport={"teleport","tp","goto","warp","jump"},
    rebirth={"rebirth","prestige","ascend"},
    click={"click","tap","hit","strike"},
}
local function matchPatterns(name)
    local lower = tostring(name):lower()
    local matches = {}
    for pat,kws in pairs(PATTERN_KEYWORDS) do
        for _,kw in ipairs(kws) do
            if lower:find(kw,1,true) then matches[#matches+1] = pat; break end
        end
    end
    return matches
end
local function analyzeRemote(remote)
    local pats = matchPatterns(remote.Name)
    if #pats == 0 then return nil end
    return {type="remote", path=remote:GetFullName(), name=remote.Name, patterns=pats,
        confidence=#pats>=2 and "high" or "medium", evidence=("Name matches %d pattern(s)"):format(#pats)}
end
local function analyzeScriptCode(entry)
    if not entry.code or #entry.code < 50 then return nil end
    local code = entry.code:lower()
    local found = {}
    if code:find("while%s+true%s+do") or code:find("while%s+wait") then found[#found+1] = "infinite_loop" end
    if code:find("fireserver") then
        local c = select(2, code:gsub("fireserver", ""))
        if c >= 3 then found[#found+1] = "repeated_fireserver_x"..c end
    end
    if code:find("sell") and code:find("fireserver") then found[#found+1] = "autosell_suspect" end
    if code:find("fireclickdetector") or code:find("fireproximityprompt") then found[#found+1] = "auto_interact" end
    if #found == 0 then return nil end
    return {type="script", path=entry.path, name=entry.name, patterns=found,
        confidence=#found>=2 and "high" or "medium", evidence=("Found %d pattern(s)"):format(#found)}
end
S.detectPatterns = function()
    local detections = {}
    local seenPaths = {}
    local t0 = os.clock()
    if S.scanner and S.scanner.remotes then
        for _,rp in ipairs(S.scanner.remotes) do
            local r = resolveByFullName(rp)
            if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
                local key = r:GetFullName()
                if not seenPaths[key] then
                    seenPaths[key] = true
                    local d = analyzeRemote(r)
                    if d then detections[#detections+1] = d end
                end
            end
        end
    end
    for _,e in ipairs(S.dumped) do
        if e.status == "ok" or e.status == "partial" then
            if not seenPaths[e.path] then
                seenPaths[e.path] = true
                local code = getScriptCode(e)
                if code then
                    local d = analyzeScriptCode({path=e.path, name=e.name, code=code})
                    if d then detections[#detections+1] = d end
                end
            end
        end
    end
    S.patterns.detections = detections
    S.patterns.lastRun = os.time()
    S.kbAddPatterns(detections)
    local dur = os.clock() - t0
    S.log("INFO", "patterns", ("Detected %d pattern(s) in %.2fs"):format(#detections, dur))
    return detections
end
S.renderPatterns = function()
    if S.unloaded or not UI.patternsList then return end
    clearGuiChildren(UI.patternsList)
    if #S.patterns.detections == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,50), BackgroundTransparency=1,
            Text="No patterns detected. Run detection first.",
            TextColor3=P.textMuted, Font=EF.Gotham, TextSize=13,
        }, UI.patternsList)
        UI.patternsStatus.Text = "0 detections"
        return
    end
    for i,d in ipairs(S.patterns.detections) do
        local item = mkCard(UI.patternsList, {size=UDim2.new(1,0,0,70), layoutOrder=i})
        local tc = (d.type == "remote") and P.accent or P.partial
        mkBadge(item, {
            size=UDim2.fromOffset(64,18), position=UDim2.new(0,14,0,12),
            text=d.type:upper(), bg=tc, textColor=P.textInverse,
        })
        new("TextLabel", {
            Size=UDim2.new(1,-220,0,18), Position=UDim2.new(0,90,0,12),
            BackgroundTransparency=1, Text=d.name, TextColor3=P.textPrimary,
            Font=EF.GothamBold, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        new("TextLabel", {
            Size=UDim2.new(1,-220,0,16), Position=UDim2.new(0,90,0,32),
            BackgroundTransparency=1, Text=table.concat(d.patterns, " - "),
            TextColor3=P.warn, Font=EF.Code, TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        new("TextLabel", {
            Size=UDim2.new(1,-220,0,14), Position=UDim2.new(0,90,0,50),
            BackgroundTransparency=1, Text=d.evidence.." - "..d.confidence,
            TextColor3=P.textMuted, Font=EF.Code, TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        local sendBtn = mkButton(item, {
            size=UDim2.fromOffset(90,28), position=UDim2.new(1,-104,0.5,-14),
            text=tr("send_ai"), bg=P.accentTint, textColor=P.accent, textSize=10,
        })
        sendBtn.MouseButton1Click:Connect(function()
            UI.chatInput.Text = "Analyze this pattern and write a complete executor script. Name: "..d.name..
                " Type: "..d.type.." Path: "..d.path.." Patterns: "..table.concat(d.patterns,", ")..
                "\nModern dark UI, toggles, config, RightShift keybind, unload, exact paths, delays, pcall. ONE ```lua block."
            S.switchView("chat")
        end)
    end
    UI.patternsStatus.Text = ("%d detection(s)"):format(#S.patterns.detections)
end
UI.patternsRunBtn.MouseButton1Click:Connect(function()
    UI.patternsStatus.Text = tr("scanning")
    trackTask(task.spawn(function()
        S.detectPatterns()
        S.renderPatterns()
    end))
end)

local function runSearch()
    local query = trim(searchBox.Text)
    clearGuiChildren(UI.searchList)
    if query == "" then UI.searchStatus.Text = tr("search_hint"); return end
    local q = query:lower()
    local matches = {}
    for _,e in ipairs(S.dumped) do
        local code = getScriptCode(e)
        local matched = false
        if e.name:lower():find(q,1,true) then matched = true end
        if e.path:lower():find(q,1,true) then matched = true end
        if code and code:lower():find(q,1,true) then matched = true end
        if matched then matches[#matches+1] = {entry=e, code=code} end
    end
    if #matches == 0 then
        UI.searchStatus.Text = ("No matches for '%s' in %d scripts"):format(query, #S.dumped)
        return
    end
    UI.searchStatus.Text = ("%d match(es) in %d scripts"):format(#matches, #S.dumped)
    for i,m in ipairs(matches) do
        if i > 100 then break end
        local item = new("Frame", {
            Size=UDim2.new(1,0,0,60), BackgroundColor3=P.surface1,
            BorderSizePixel=0, LayoutOrder=i,
        }, UI.searchList)
        corner(item, 8); stroke(item, P.border, 1)
        new("TextLabel", {
            Size=UDim2.new(1,-140,0,18), Position=UDim2.new(0,14,0,8),
            BackgroundTransparency=1, Text=m.entry.name.." ["..m.entry.class.."]",
            TextColor3=P.textPrimary, Font=EF.GothamBold, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        new("TextLabel", {
            Size=UDim2.new(1,-140,0,14), Position=UDim2.new(0,14,0,28),
            BackgroundTransparency=1, Text=cut(m.entry.path,80),
            TextColor3=P.textMuted, Font=EF.Code, TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        new("TextLabel", {
            Size=UDim2.new(1,-140,0,12), Position=UDim2.new(0,14,0,44),
            BackgroundTransparency=1,
            Text=m.code and (cut(m.code,100):gsub("\n"," ")) or "(not loaded)",
            TextColor3=P.textSecondary, Font=EF.Code, TextSize=9,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        local openBtn = mkButton(item, {
            size=UDim2.fromOffset(110,28), position=UDim2.new(1,-126,0.5,-14),
            text="Open", bg=P.accentTint, textColor=P.accent, textSize=11,
        })
        openBtn.MouseButton1Click:Connect(function()
            S.openScriptViewer(m.entry.name.." - "..cut(m.entry.path,60), m.code or "(not loaded)")
        end)
    end
end
UI.searchRunBtn.MouseButton1Click:Connect(runSearch)
searchBox.FocusLost:Connect(function(enter) if enter then runSearch() end end)

local worldFilterQ = ""
S.renderWorld = function()
    if S.unloaded or not UI.worldList then return end
    clearGuiChildren(UI.worldList)
    local q = worldFilterQ:lower()
    local shown = 0
    new("TextLabel", {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text="PLAYERS",
        TextColor3=P.accent, Font=EF.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0,
    }, UI.worldList)
    shown = shown + 1
    for _,p in ipairs(Players:GetPlayers()) do
        if q == "" or p.Name:lower():find(q,1,true) then
            shown = shown + 1
            local b = new("TextButton", {
                Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
                Text=p.Name, TextColor3=P.textPrimary,
                Font=EF.Gotham, TextSize=11,
                TextXAlignment=Enum.TextXAlignment.Left,
                BorderSizePixel=0, LayoutOrder=shown,
            }, UI.worldList)
            pad(b, 0, 0, 10, 0)
            b.MouseEnter:Connect(function() b.BackgroundTransparency = 0; b.BackgroundColor3 = P.surfaceHover end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
            b.MouseButton1Click:Connect(function()
                UI.worldDetailTitle.Text = p.Name
                local lines = {}
                lines[#lines+1] = "Full name: "..p:GetFullName()
                lines[#lines+1] = "UserId: "..tostring(p.UserId)
                lines[#lines+1] = "Team: "..(p.Team and p.Team.Name or "none")
                if p.Character then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then lines[#lines+1] = "HP: "..math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) end
                end
                UI.worldDetailBody.Text = table.concat(lines, "\n")
            end)
        end
    end
    new("TextLabel", {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text="WORKSPACE",
        TextColor3=P.accent, Font=EF.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=shown+1,
    }, UI.worldList)
    shown = shown + 1
    local cnt = 0
    for _,c in ipairs(workspace:GetChildren()) do
        cnt = cnt + 1
        if cnt > 100 then break end
        if q == "" or c.Name:lower():find(q,1,true) then
            shown = shown + 1
            local b = new("TextButton", {
                Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
                Text=c.Name.."  ["..c.ClassName.."]",
                TextColor3=P.textPrimary, Font=EF.Gotham, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Left,
                BorderSizePixel=0, LayoutOrder=shown,
            }, UI.worldList)
            pad(b, 0, 0, 10, 0)
            b.MouseEnter:Connect(function() b.BackgroundTransparency = 0; b.BackgroundColor3 = P.surfaceHover end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
            b.MouseButton1Click:Connect(function()
                UI.worldDetailTitle.Text = c.Name
                local lines = {}
                pcall(function()
                    lines[#lines+1] = "Path: "..c:GetFullName()
                    lines[#lines+1] = "Class: "..c.ClassName
                    if c:IsA("BasePart") then
                        lines[#lines+1] = string.format("Position: (%.1f, %.1f, %.1f)", c.Position.X, c.Position.Y, c.Position.Z)
                        lines[#lines+1] = "Size: "..tostring(c.Size)
                    end
                    for k,v in pairs(c:GetAttributes()) do
                        lines[#lines+1] = "attr: "..k.." = "..tostring(v)
                    end
                end)
                UI.worldDetailBody.Text = table.concat(lines, "\n")
            end)
        end
    end
    UI.worldStatus.Text = "Showing "..shown.." items"
end
UI.worldRefreshBtn.MouseButton1Click:Connect(function()
    S.renderWorld(); S.showToast(tr("refreshed"))
end)
local worldFilterToken = 0
worldFilterBox:GetPropertyChangedSignal("Text"):Connect(function()
    worldFilterQ = worldFilterBox.Text
    worldFilterToken = worldFilterToken + 1
    local my = worldFilterToken
    task.delay(0.15, function()
        if my == worldFilterToken and not S.unloaded then S.renderWorld() end
    end)
end)

S.runAsync = function(id, fn, statusSetter)
    S.testCancel[id] = false
    table.insert(S.activeTests, id)
    trackTask(task.spawn(function()
        local function cancelled() return S.unloaded or S.testCancel[id] == true end
        local ok, err = pcall(fn, cancelled)
        for i,v in ipairs(S.activeTests) do
            if v == id then table.remove(S.activeTests, i); break end
        end
        if cancelled() then
            if statusSetter then statusSetter("stopped") end
        elseif not ok then
            S.log("ERROR", id, tostring(err))
            if statusSetter then statusSetter("error") end
        end
        S.updateDash()
    end))
end
local function bindStop(btn, id, statusLabel)
    btn.MouseButton1Click:Connect(function()
        S.testCancel[id] = true
        if statusLabel then statusLabel.Text = "Status: stopping..." end
    end)
end

UI.resCards.snap[2].MouseButton1Click:Connect(function()
    local snap = {}
    for _,o in ipairs(player:GetDescendants()) do
        if o:IsA("ValueBase") then snap[o:GetFullName()] = o.Value end
    end
    S.snapshot = snap
    local n = 0
    for _ in pairs(snap) do n = n + 1 end
    S.logTest("resource", "Snapshot taken - "..n.." values")
    UI.resCards.snap[4].Text = "Status: "..n.." values snapshotted"
end)
bindStop(UI.resCards.snap[3], "Snapshot", UI.resCards.snap[4])
UI.resCards.compare[2].MouseButton1Click:Connect(function()
    if not S.snapshot then UI.resCards.compare[4].Text = "Status: no snapshot"; return end
    local changes = 0
    for name,old in pairs(S.snapshot) do
        local o = resolveByFullName(name)
        if o and o:IsA("ValueBase") and o.Value ~= old then
            changes = changes + 1
            S.logTest("resource", ("Change: %s | %s -> %s"):format(name, tostring(old), tostring(o.Value)))
        end
    end
    UI.resCards.compare[4].Text = "Status: "..changes.." changes detected"
end)
bindStop(UI.resCards.compare[3], "Compare", UI.resCards.compare[4])
UI.resCards.dup[2].MouseButton1Click:Connect(function()
    if #S.remotes == 0 then
        UI.resCards.dup[4].Text = "Status: no spy data"
        return
    end
    local counts, repeats = {}, {}
    for _,r in ipairs(S.remotes) do
        local k = (r.path or "?")..":"..(r.method or "?").."("..(r.args or "")..")"
        counts[k] = (counts[k] or 0) + 1
    end
    for k,n in pairs(counts) do
        if n >= 2 then repeats[#repeats+1] = {k=k, n=n} end
    end
    table.sort(repeats, function(a,b) return a.n > b.n end)
    local shown = math.min(#repeats, 8)
    S.logTest("resource", "Duplicate signatures: "..#repeats)
    for i=1,shown do S.logTest("resource", ("  x%d  %s"):format(repeats[i].n, cut(repeats[i].k,120))) end
    UI.resCards.dup[4].Text = ("Status: %d repeated sigs in %d calls"):format(#repeats, #S.remotes)
end)
UI.resCards.dup[3].MouseButton1Click:Connect(function()
    UI.resCards.dup[4].Text = "Status: idle"
end)

UI.protCards.owner[2].MouseButton1Click:Connect(function()
    S.runAsync("OwnershipScan", function(cancelled)
        local found = {}
        for _,o in ipairs(workspace:GetDescendants()) do
            if cancelled() then return end
            if o:IsA("BasePart") or o:IsA("Model") then
                local ok,ow = pcall(function() return o:GetAttribute("Owner") end)
                local ok2,owid = pcall(function() return o:GetAttribute("OwnerId") end)
                if (ok and ow) or (ok2 and owid) then
                    found[#found+1] = o:GetFullName().." (Owner="..tostring(ow or owid)..")"
                end
            end
            if #found >= 40 then break end
        end
        S.logTest("protection", "Ownership scan found "..#found.." tagged")
        for _,f in ipairs(found) do S.logTest("protection", "  "..f) end
        UI.protCards.owner[4].Text = "Status: "..#found.." tagged"
    end, function(s) UI.protCards.owner[4].Text = "Status: "..s end)
end)
bindStop(UI.protCards.owner[3], "OwnershipScan", UI.protCards.owner[4])
UI.protCards.access[2].MouseButton1Click:Connect(function()
    S.runAsync("AccessScan", function(cancelled)
        local n = 0
        for _,o in ipairs(workspace:GetDescendants()) do
            if cancelled() then return end
            if o:IsA("BasePart") or o:IsA("Model") then
                for _,attr in ipairs({"Locked","Owned","Private","Restricted"}) do
                    local ok,v = pcall(function() return o:GetAttribute(attr) end)
                    if ok and v then
                        n = n + 1
                        S.logTest("protection", "  "..o:GetFullName().." "..attr.."="..tostring(v))
                    end
                end
            end
            if n >= 30 then break end
        end
        UI.protCards.access[4].Text = "Status: "..n.." restrictions"
    end, function(s) UI.protCards.access[4].Text = "Status: "..s end)
end)
bindStop(UI.protCards.access[3], "AccessScan", UI.protCards.access[4])
UI.protCards.revert[2].MouseButton1Click:Connect(function()
    S.runAsync("RevertTest", function(cancelled)
        local target
        for _,o in ipairs(workspace:GetDescendants()) do
            if cancelled() then return end
            if o:IsA("BasePart") and o.Name:lower():find("part",1,true) then target = o; break end
        end
        if not target then UI.protCards.revert[4].Text = "Status: no target"; return end
        local orig = target.Transparency
        local success, err = pcall(function()
            target.Transparency = 0.5
            UI.protCards.revert[4].Text = "Status: running"
            local t0 = os.clock()
            while os.clock()-t0 < CFG.testDuration do
                if cancelled() then break end
                task.wait(0.1)
            end
            UI.protCards.revert[4].Text = "Status: observed="..tostring(target.Transparency)
        end)
        pcall(function() target.Transparency = orig end)
        if not success then UI.protCards.revert[4].Text = "Status: error "..tostring(err) end
    end, function(s) UI.protCards.revert[4].Text = "Status: "..s end)
end)
bindStop(UI.protCards.revert[3], "RevertTest", UI.protCards.revert[4])

local SNAP_DIR = CFG.dir.."/snapshots"
ensureDir(SNAP_DIR)
local function listSnapshots()
    if not hasFS() then return {} end
    local out = {}
    if type(listfiles) == "function" then
        local ok,files = pcall(listfiles, SNAP_DIR)
        if ok and type(files)=="table" then
            for _,f in ipairs(files) do
                local name = f:match("([^/\\]+)$") or f
                if name:match("^snapshot_%d+%.json$") then out[#out+1] = name end
            end
        end
    end
    table.sort(out, function(a,b) return a > b end)
    return out
end
local function validateSnapshot(data)
    if type(data) ~= "table" then return false, "not a table" end
    if type(data.convos) ~= "table" then return false, "missing convos" end
    for _,c in ipairs(data.convos) do
        if type(c) ~= "table" then return false, "convo not table" end
        if type(c.id) ~= "string" then return false, "convo.id" end
        if type(c.messages) ~= "table" then return false, "convo.messages" end
        for _,m in ipairs(c.messages) do
            if type(m) ~= "table" then return false, "msg" end
            if m.r ~= "user" and m.r ~= "ai" then return false, "role" end
            if type(m.t) ~= "string" then return false, "text" end
        end
    end
    return true, nil
end
local function renderSnapshots()
    if S.unloaded or not UI.snapList then return end
    clearGuiChildren(UI.snapList)
    local files = listSnapshots()
    UI.snapStatus.Text = ("%d snapshot(s)"):format(#files)
    if #files == 0 then
        new("TextLabel", {
            Size=UDim2.new(1,0,0,60), BackgroundTransparency=1,
            Text="No snapshots yet. Click 'Save current'.",
            TextColor3=P.textMuted, Font=EF.Gotham, TextSize=13,
            TextWrapped=true, TextYAlignment=Enum.TextYAlignment.Top,
        }, UI.snapList)
        return
    end
    for i,fname in ipairs(files) do
        local item = new("Frame", {
            Size=UDim2.new(1,0,0,56), BackgroundColor3=P.surface1,
            BorderSizePixel=0, LayoutOrder=i,
        }, UI.snapList)
        corner(item, 8); stroke(item, P.border, 1)
        new("TextLabel", {
            Size=UDim2.new(1,-400,0,20), Position=UDim2.new(0,14,0,8),
            BackgroundTransparency=1, Text=fname, TextColor3=P.textPrimary,
            Font=EF.GothamMedium, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
        }, item)
        local diffBtn = mkButton(item, {size=UDim2.fromOffset(110,28), position=UDim2.new(1,-340,0.5,-14), text="Diff", bg=P.warnTint, textColor=P.warn, textSize=11})
        local loadBtn = mkButton(item, {size=UDim2.fromOffset(100,28), position=UDim2.new(1,-220,0.5,-14), text="Load", bg=P.accentTint, textColor=P.accent, textSize=11})
        local delBtn = mkButton(item, {size=UDim2.fromOffset(100,28), position=UDim2.new(1,-110,0.5,-14), text="Delete", bg=P.dangerTint, textColor=P.danger, textSize=11})
        loadBtn.MouseButton1Click:Connect(function()
            local raw = safeRead(SNAP_DIR.."/"..fname)
            if not raw then S.showToast(tr("load_failed"), "error"); return end
            local ok,data = pcall(Http.JSONDecode, Http, raw)
            if not ok then S.showToast(tr("corrupt_json"), "error"); return end
            local valid, err = validateSnapshot(data)
            if not valid then S.showToast(string.format(tr("invalid_snapshot"), tostring(err)), "error"); return end
            S.convos = data.convos
            if data.currentConvoId then S.currentConvoId = data.currentConvoId end
            if type(data.customTemplates) == "table" then
                local validTpls = {}
                for _,t in ipairs(data.customTemplates) do
                    if type(t)=="table" and type(t.prompt)=="string" then
                        if not t.id then t.id = genId("tpl") end
                        validTpls[#validTpls+1] = t
                    end
                end
                S.customTemplates = validTpls
            end
            S.renderConvoList(); S.renderChat()
            if S.renderTemplates then S.renderTemplates() end
            S.showToast(tr("snapshot_loaded"), "success")
        end)
        delBtn.MouseButton1Click:Connect(function()
            pcall(function() if type(delfile)=="function" then delfile(SNAP_DIR.."/"..fname) end end)
            renderSnapshots()
            S.showToast(tr("snapshot_deleted"), "success")
        end)
        diffBtn.MouseButton1Click:Connect(function()
            local raw = safeRead(SNAP_DIR.."/"..fname)
            if not raw then return end
            local ok,data = pcall(Http.JSONDecode, Http, raw)
            if not ok or type(data) ~= "table" then return end
            local oldText = Http:JSONEncode(data.convos or {})
            local newText = Http:JSONEncode(S.convos)
            S.openDiffViewer("Snapshot "..fname.." vs Current", oldText, newText)
        end)
    end
end
UI.snapSaveBtn.MouseButton1Click:Connect(function()
    if not hasFS() then S.showToast(tr("no_filesystem"), "error"); return end
    local data = {convos=S.convos, currentConvoId=S.currentConvoId, customTemplates=S.customTemplates, placeId=game.PlaceId, savedAt=os.time(), version="v13.0"}
    local fname = "snapshot_"..os.time()..".json"
    local ok = safeWrite(SNAP_DIR.."/"..fname, Http:JSONEncode(data))
    if ok then S.showToast(string.format(tr("saved"), fname), "success")
    else S.showToast(tr("save_failed"), "error") end
    renderSnapshots()
end)
UI.snapRefreshBtn.MouseButton1Click:Connect(function() renderSnapshots() end)
S.renderSnapshots = renderSnapshots

S.updateSafety = function()
    if S.unloaded or not UI.safeInfo then return end
    local nTasks = 0
    for _,t in ipairs(S.tasks) do if not isTaskDead(t) then nTasks = nTasks + 1 end end
    local ok_n = 0
    for _,e in ipairs(S.dumped) do
        if e.status == "ok" or e.status == "partial" then ok_n = ok_n + 1 end
    end
    UI.safeInfo.Text = table.concat({
        "Connections: "..#S.conns, "Tracked tasks: "..nTasks,
        "Active tests: "..#S.activeTests, "Remote spy: "..(S.spyHooked and "ON" or "off"),
        "AI busy: "..(S.busy and "yes" or "no"),
        "Provider: "..CFG.modelProvider.."/"..CFG.model,
        "Pending HTTP: "..tostring(S._zombieHTTP or 0),
        "Cache (mem): "..tostring(S.countCache()),
        "Dumped: "..#S.dumped.." / "..ok_n,
        "KB scripts: "..#KB.scripts.." - remotes: "..#KB.remotes,
        "Conversations: "..#S.convos,
    }, "\n")
end
UI.safeStopBtn.MouseButton1Click:Connect(function()
    for id in pairs(S.testCancel) do S.testCancel[id] = true end
    for _,t in ipairs(S.tasks) do pcall(function() task.cancel(t) end) end
    S.tasks = {}; S.activeTests = {}; S.busy = false
    scanRunning = false; dumpScanning = false
    decRunning = false; decCancel = true
    if UI.chatSendBtn then UI.chatSendBtn.Text = "->"; paintButton(UI.chatSendBtn, P.accent, P.textInverse) end
    if UI.decAllBtn then UI.decAllBtn.Text = tr("decompile_all"); paintButton(UI.decAllBtn, P.accentTint, P.accent) end
    if UI.scanRunBtn then UI.scanRunBtn.Text = tr("scan_game") end
    if UI.dumpScanBtn then UI.dumpScanBtn.Text = tr("scan_scripts") end
    S.showToast("All tasks cancelled", "success")
    S.updateDash()
    if S.updateSafety then S.updateSafety() end
end)
UI.safeRevertBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local c = player.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16; h.JumpPower = 50 end
        end
    end)
    S.showToast("Reverted local", "success")
end)
UI.safeClearCacheBtn.MouseButton1Click:Connect(function()
    S.cache = {}; memoryCacheOrder = {}
    for _,e in ipairs(S.dumped) do
        e.status = "pending"; e.code = nil; e.codeCached = false
    end
    S.renderDump(); S.updateDecStatus(); S.updateDash()
    S.showToast("Cache cleared", "success")
end)
UI.safePurgeKBtn.MouseButton1Click:Connect(function()
    KB.scripts = {}; KB.remotes = {}; KB.analysis = {}; KB.patterns = {}; KB.sessions = {}
    for k,_ in pairs(KB) do pcall(kbFlushNow, k) end
    S.showToast("KB purged", "success")
    if S.updateSafety then S.updateSafety() end
end)
UI.safeHideBtn.MouseButton1Click:Connect(function() setGuiVisible(false) end)

UI.cfgScroll = new("ScrollingFrame", {
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=P.border,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.cfgView)
pad(UI.cfgScroll, 24, 24, 24, 24)
new("UIListLayout", {Padding=UDim.new(0,12), SortOrder=Enum.SortOrder.LayoutOrder}, UI.cfgScroll)
local cfgOrder = 0
local function cfgSection(title)
    cfgOrder = cfgOrder + 1
    new("TextLabel", {
        Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Text=title,
        TextColor3=P.textMuted, Font=EF.GothamBold, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=cfgOrder,
    }, UI.cfgScroll)
end
local function cfgRow(title, sub)
    cfgOrder = cfgOrder + 1
    local r = mkCard(UI.cfgScroll, {size=UDim2.new(1,0,0,60), layoutOrder=cfgOrder})
    new("TextLabel", {
        Size=UDim2.new(1,-240,0,20), Position=UDim2.new(0,20,0,8),
        BackgroundTransparency=1, Text=title, TextColor3=P.textPrimary,
        Font=EF.GothamMedium, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
    }, r)
    new("TextLabel", {
        Size=UDim2.new(1,-240,0,18), Position=UDim2.new(0,20,0,30),
        BackgroundTransparency=1, Text=sub, TextColor3=P.textMuted,
        Font=EF.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
    }, r)
    return r
end
local function cfgToggle(parent, initial, onChange)
    local tr_btn = new("TextButton", {
        Size=UDim2.fromOffset(46,24), Position=UDim2.new(1,-66,0.5,-12),
        BackgroundColor3=initial and P.accent or P.borderLight,
        Text="", AutoButtonColor=false, BorderSizePixel=0,
    }, parent)
    corner(tr_btn, 12)
    local kn = new("Frame", {
        Size=UDim2.fromOffset(18,18),
        Position=initial and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
    }, tr_btn)
    corner(kn, 9)
    local on = initial
    tr_btn.MouseButton1Click:Connect(function()
        on = not on
        M.tween(tr_btn, M.fast, {BackgroundColor3=on and P.accent or P.borderLight})
        M.tween(kn, M.fast, {Position=on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)})
        if onChange then onChange(on) end
    end)
    return tr_btn
end

cfgSection("AI CONFIGURATION")
local providerRow = cfgRow(tr("model_provider"), "Current: "..CFG.modelProvider)
local providerBtn = mkButton(providerRow, {
    size=UDim2.fromOffset(150,32), position=UDim2.new(1,-170,0.5,-16),
    text=CFG.modelProvider:upper(), bg=P.accentTint, textColor=P.accent, textSize=11,
})
providerBtn.MouseButton1Click:Connect(function()
    local providers = {"gemini","openai","anthropic"}
    local idx = 1
    for i,p in ipairs(providers) do if p == CFG.modelProvider then idx = i end end
    idx = idx % #providers + 1
    CFG.modelProvider = providers[idx]
    local firstModel = nil
    for m,_ in pairs(CFG.models[CFG.modelProvider]) do firstModel = m; break end
    if firstModel then CFG.model = firstModel end
    providerBtn.Text = CFG.modelProvider:upper()
    saveConfig()
    S.showToast("Provider: "..CFG.modelProvider, "success")
end)
local modelRow = cfgRow("AI Model", "Current: "..CFG.model)
local modelBtn = mkButton(modelRow, {
    size=UDim2.fromOffset(220,32), position=UDim2.new(1,-240,0.5,-16),
    text=CFG.model, bg=P.accentTint, textColor=P.accent, textSize=10,
})
modelBtn.MouseButton1Click:Connect(function()
    local models = {}
    for m,_ in pairs(CFG.models[CFG.modelProvider]) do models[#models+1] = m end
    if #models == 0 then return end
    local idx = 1
    for i,m in ipairs(models) do if m == CFG.model then idx = i end end
    idx = idx % #models + 1
    CFG.model = models[idx]
    modelBtn.Text = CFG.model
    saveConfig()
    S.showToast("Model: "..CFG.model, "success")
end)
local apiKeyRow = cfgRow("API Key ("..CFG.modelProvider..")", maskKey(getCurrentApiKey()))
local _apiKeyWrap, apiKeyBox = mkInput(apiKeyRow, {
    size=UDim2.fromOffset(220,32), position=UDim2.new(1,-240,0.5,-16),
    placeholder="Paste API key...", text=maskKey(getCurrentApiKey()),
})
apiKeyBox.Focused:Connect(function()
    apiKeyBox.Text = ""
    apiKeyBox.PlaceholderText = tr("paste_then_click")
end)
apiKeyBox.FocusLost:Connect(function()
    local v = trim(apiKeyBox.Text)
    if v ~= "" then
        CFG.apiKeys[CFG.modelProvider] = v
        saveConfig()
        S.showToast("API key saved", "success")
    end
    apiKeyBox.Text = maskKey(getCurrentApiKey())
end)
local tempRow = cfgRow("AI Temperature", "0 = precise, 1 = creative")
local tempBox = new("TextBox", {
    Size=UDim2.fromOffset(70,32), Position=UDim2.new(1,-90,0.5,-16),
    BackgroundColor3=P.accentTint, Text=tostring(CFG.temp), TextColor3=P.accent,
    Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Center,
    ClearTextOnFocus=false, BorderSizePixel=0,
}, tempRow)
corner(tempBox, 8)
tempBox.FocusLost:Connect(function()
    local v = tonumber(tempBox.Text)
    if v and v >= 0 and v <= 2 then CFG.temp = v; saveConfig()
    else tempBox.Text = tostring(CFG.temp) end
end)

cfgSection("AI MEMORY & TOOLS")
local memoryRow = cfgRow(tr("ai_memory_toggle"), "Long-term learning across sessions")
cfgToggle(memoryRow, CFG.aiMemoryEnabled, function(v) CFG.aiMemoryEnabled = v; saveConfig() end)
local marketRow = cfgRow(tr("marketplace_toggle"), "Script library")
cfgToggle(marketRow, CFG.marketplaceEnabled, function(v) CFG.marketplaceEnabled = v; saveConfig() end)
local debugRow = cfgRow(tr("debugger_toggle"), "Remote debugging tools")
cfgToggle(debugRow, CFG.debuggerEnabled, function(v) CFG.debuggerEnabled = v; saveConfig() end)

cfgSection("BEHAVIOUR")
local ctxRow = cfgRow("AI auto-context", "Inject game context")
cfgToggle(ctxRow, CFG.contextOn, function(v) CFG.contextOn = v; saveConfig() end)
local ragRow = cfgRow("RAG knowledge base", "Search past data")
cfgToggle(ragRow, CFG.ragEnabled, function(v) CFG.ragEnabled = v; saveConfig() end)
local autoScanRow = cfgRow("Auto scan on startup", "Run scanner at boot")
cfgToggle(autoScanRow, CFG.autoScan, function(v) CFG.autoScan = v; saveConfig() end)
local autoSpyRow = cfgRow("Auto start Remote Spy", "Hook __namecall")
cfgToggle(autoSpyRow, CFG.autoSpy, function(v)
    CFG.autoSpy = v; saveConfig()
    if v then if not S.spyHooked and S.startSpy then S.startSpy() end
    else if S.spyHooked and S.stopSpy then S.stopSpy() end end
end)
local saveUnloadRow = cfgRow("Save on unload", "Persist conversations")
cfgToggle(saveUnloadRow, CFG.saveOnUnload, function(v) CFG.saveOnUnload = v; saveConfig() end)

cfgSection("GENERAL")
local langRow = cfgRow(tr("language"), "Interface language")
local langBtn = mkButton(langRow, {
    size=UDim2.fromOffset(120,32), position=UDim2.new(1,-160,0.5,-16),
    text=(CFG.lang and CFG.lang:upper() or "EN"), bg=P.accentTint, textColor=P.accent, textSize=11,
})
langBtn.MouseButton1Click:Connect(function()
    local cur = CFG.lang or "en"
    local nextLang = (cur == "en") and "fr" or "en"
    CFG.lang = nextLang
    langBtn.Text = nextLang:upper()
    saveConfig()
    if S.refreshLocale then pcall(S.refreshLocale) end
    S.showToast(string.format(tr("language_changed"), nextLang:upper()), "success")
end)
local resetBtn = mkButton(UI.cfgScroll, {
    size=UDim2.new(1,0,0,44), text=tr("reset_settings"), layoutOrder=cfgOrder+1,
})
resetBtn.MouseButton1Click:Connect(function()
    CFG.model = "gemini-flash-lite-latest"
    CFG.modelProvider = "gemini"
    CFG.temp = 0.8; CFG.keybind = "Insert"
    CFG.contextOn = true; CFG.ragEnabled = true
    CFG.aiMemoryEnabled = true; CFG.marketplaceEnabled = true; CFG.debuggerEnabled = true
    CFG.autoScan = true; CFG.autoSpy = true; CFG.saveOnUnload = true
    modelBtn.Text = CFG.model
    providerBtn.Text = CFG.modelProvider:upper()
    tempBox.Text = tostring(CFG.temp)
    saveConfig()
    S.showToast("Settings reset", "success")
end)

local KEYS = {"Insert","Home","End","Delete","PageUp","PageDown","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12","RightShift","LeftShift","RightControl","LeftControl","RightAlt","LeftAlt","Tab","Backquote"}
UI.keyPicker = new("Frame", {
    Size=UDim2.fromOffset(180,320), BackgroundColor3=P.surface1,
    BorderSizePixel=0, Visible=false, ZIndex=450,
}, UI.gui)
corner(UI.keyPicker, 10); stroke(UI.keyPicker, P.border, 1)
UI.keyPickerList = new("ScrollingFrame", {
    Size=UDim2.new(1,-12,1,-12), Position=UDim2.new(0,6,0,6),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
    CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, UI.keyPicker)
new("UIListLayout", {Padding=UDim.new(0,2)}, UI.keyPickerList)
for i,k in ipairs(KEYS) do
    local b = new("TextButton", {
        Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, Text=k,
        TextColor3=P.textPrimary, Font=EF.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=i, BorderSizePixel=0,
    }, UI.keyPickerList)
    corner(b, 4); pad(b, 0, 0, 10, 0)
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0; b.BackgroundColor3 = P.surfaceHover end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    b.MouseButton1Click:Connect(function()
        CFG.keybind = k
        UI.keyChip.Text = "["..k.."]"
        S.toggleKey = EK[k] or EK.Insert
        saveConfig()
        UI.keyPicker.Visible = false
    end)
end
UI.keyChip.MouseButton1Click:Connect(function()
    UI.keyPicker.Visible = not UI.keyPicker.Visible
    if UI.keyPicker.Visible then
        UI.keyPicker.Position = UDim2.fromOffset(UI.keyChip.AbsolutePosition.X, UI.keyChip.AbsolutePosition.Y - 330)
    end
end)

UI.scriptViewer = new("Frame", {
    Size=UDim2.fromOffset(900,640), Position=UDim2.new(0.5,-450,0.5,-320),
    BackgroundColor3=P.surface1, BorderSizePixel=0, Visible=false, ZIndex=400,
}, UI.gui)
corner(UI.scriptViewer, 14); stroke(UI.scriptViewer, P.accent, 1)
UI.viewerHeader = new("Frame", {
    Size=UDim2.new(1,0,0,46), BackgroundColor3=P.surface2, BorderSizePixel=0, ZIndex=401,
}, UI.scriptViewer)
corner(UI.viewerHeader, 14)
UI.viewerTitle = new("TextLabel", {
    Size=UDim2.new(1,-260,1,0), Position=UDim2.new(0,20,0,0),
    BackgroundTransparency=1, Text=tr("script_viewer"), TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=402,
}, UI.viewerHeader)
UI.viewerCopyBtn = mkButton(UI.viewerHeader, {
    size=UDim2.fromOffset(80,28), position=UDim2.new(1,-170,0.5,-14),
    text=tr("copy"), bg=P.accentTint, textColor=P.accent, textSize=11, zIndex=402,
})
UI.viewerSendBtn = mkButton(UI.viewerHeader, {
    size=UDim2.fromOffset(80,28), position=UDim2.new(1,-86,0.5,-14),
    text=tr("send_ai"), textSize=11, zIndex=402,
})
UI.viewerCloseBtn = new("TextButton", {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-32,0.5,-14),
    BackgroundColor3=P.dangerTint, Text="x", TextColor3=P.danger,
    Font=EF.GothamBold, TextSize=12, BorderSizePixel=0, AutoButtonColor=false, ZIndex=402,
}, UI.viewerHeader)
corner(UI.viewerCloseBtn, 6); stroke(UI.viewerCloseBtn, P.danger, 1)
UI.viewerScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-24,1,-62), Position=UDim2.new(0,12,0,54),
    BackgroundColor3=P.codeBg, BorderSizePixel=0, ScrollBarThickness=6,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.XY, ZIndex=402,
}, UI.scriptViewer)
corner(UI.viewerScroll, 10); stroke(UI.viewerScroll, P.border, 1)
UI.viewerCode = new("TextBox", {
    Size=UDim2.new(1,0,0,0), BackgroundTransparency=1, Text="",
    TextColor3=P.codeText, Font=EF.Code, TextSize=12,
    TextWrapped=false, MultiLine=true, TextEditable=false,
    ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, AutomaticSize=Enum.AutomaticSize.XY, ZIndex=402,
}, UI.viewerScroll)
pad(UI.viewerCode, 16, 16, 18, 18)
S.openScriptViewer = function(title, code)
    UI.viewerTitle.Text = title
    UI.viewerCode.Text = code or "-- No code"
    UI.scriptViewer.Visible = true
end
UI.viewerCloseBtn.MouseButton1Click:Connect(function() UI.scriptViewer.Visible = false end)
UI.viewerCopyBtn.MouseButton1Click:Connect(function()
    local clip = clipFn()
    if clip then
        pcall(clip, UI.viewerCode.Text)
        UI.viewerCopyBtn.Text = tr("copied")
        task.delay(1.5, function() UI.viewerCopyBtn.Text = tr("copy") end)
    end
end)
UI.viewerSendBtn.MouseButton1Click:Connect(function()
    UI.chatInput.Text = "Analyze this script:\n"..UI.viewerCode.Text
    UI.scriptViewer.Visible = false
    S.switchView("chat")
end)

UI.chatViewer = new("Frame", {
    Size=UDim2.fromScale(0.97,0.95), Position=UDim2.fromScale(0.5,0.5),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=P.surface1,
    BorderSizePixel=0, Visible=false, ZIndex=600,
}, UI.gui)
corner(UI.chatViewer, 14); stroke(UI.chatViewer, P.accent, 1)
UI.chatViewerHeader = new("Frame", {
    Size=UDim2.new(1,0,0,46), BackgroundColor3=P.surface2, BorderSizePixel=0, ZIndex=601,
}, UI.chatViewer)
corner(UI.chatViewerHeader, 14)
UI.chatViewerTitle = new("TextLabel", {
    Size=UDim2.new(1,-300,1,0), Position=UDim2.new(0,20,0,0),
    BackgroundTransparency=1, Text="Full Response", TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=602,
}, UI.chatViewerHeader)
UI.chatViewerCopyBtn = mkButton(UI.chatViewerHeader, {
    size=UDim2.fromOffset(90,28), position=UDim2.new(1,-210,0.5,-14),
    text="Copy all", bg=P.accentTint, textColor=P.accent, textSize=11, zIndex=602,
})
UI.chatViewerSaveBtn = mkButton(UI.chatViewerHeader, {
    size=UDim2.fromOffset(70,28), position=UDim2.new(1,-116,0.5,-14),
    text="Save", textSize=11, zIndex=602,
})
UI.chatViewerCloseBtn = new("TextButton", {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-32,0.5,-14),
    BackgroundColor3=P.dangerTint, Text="x", TextColor3=P.danger,
    Font=EF.GothamBold, TextSize=12, BorderSizePixel=0, AutoButtonColor=false, ZIndex=602,
}, UI.chatViewerHeader)
corner(UI.chatViewerCloseBtn, 6); stroke(UI.chatViewerCloseBtn, P.danger, 1)
UI.chatViewerScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-24,1,-62), Position=UDim2.new(0,12,0,54),
    BackgroundColor3=P.codeBg, BorderSizePixel=0, ScrollBarThickness=6,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.XY, ZIndex=601,
}, UI.chatViewer)
corner(UI.chatViewerScroll, 10); stroke(UI.chatViewerScroll, P.border, 1)
UI.chatViewerCode = new("TextBox", {
    Size=UDim2.new(1,0,0,0), BackgroundTransparency=1, Text="",
    TextColor3=P.codeText, Font=EF.Code, TextSize=12,
    TextWrapped=false, MultiLine=true, TextEditable=false,
    ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, AutomaticSize=Enum.AutomaticSize.XY, ZIndex=602,
}, UI.chatViewerScroll)
pad(UI.chatViewerCode, 16, 16, 18, 18)
S.openChatViewer = function(fullText)
    UI.chatViewerCode.Text = fullText
    UI.chatViewer.Visible = true
end
UI.chatViewerCloseBtn.MouseButton1Click:Connect(function() UI.chatViewer.Visible = false end)
UI.chatViewerCopyBtn.MouseButton1Click:Connect(function()
    local clip = clipFn()
    if clip then pcall(clip, UI.chatViewerCode.Text); S.showToast(tr("response_copied"), "success") end
end)
UI.chatViewerSaveBtn.MouseButton1Click:Connect(function()
    if not hasFS() then S.showToast(tr("no_filesystem"), "error"); return end
    ensureDir(CFG.dir)
    local fname = CFG.dir.."/response_"..os.time()..".txt"
    local ok = safeWrite(fname, UI.chatViewerCode.Text)
    S.showToast(ok and string.format(tr("saved_response"), fname) or tr("save_failed"), ok and "success" or "error")
end)

UI.diffViewer = new("Frame", {
    Size=UDim2.fromScale(0.9,0.85), Position=UDim2.fromScale(0.5,0.5),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=P.surface1,
    BorderSizePixel=0, Visible=false, ZIndex=700,
}, UI.gui)
corner(UI.diffViewer, 14); stroke(UI.diffViewer, P.warn, 1)
UI.diffHeader = new("Frame", {
    Size=UDim2.new(1,0,0,46), BackgroundColor3=P.surface2, BorderSizePixel=0, ZIndex=701,
}, UI.diffViewer)
corner(UI.diffHeader, 14)
UI.diffTitle = new("TextLabel", {
    Size=UDim2.new(1,-120,1,0), Position=UDim2.new(0,20,0,0),
    BackgroundTransparency=1, Text="Diff Viewer", TextColor3=P.textPrimary,
    Font=EF.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=702,
}, UI.diffHeader)
UI.diffCloseBtn = new("TextButton", {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-32,0.5,-14),
    BackgroundColor3=P.dangerTint, Text="x", TextColor3=P.danger,
    Font=EF.GothamBold, TextSize=12, BorderSizePixel=0, AutoButtonColor=false, ZIndex=702,
}, UI.diffHeader)
corner(UI.diffCloseBtn, 6); stroke(UI.diffCloseBtn, P.danger, 1)
UI.diffWarning = new("TextLabel", {
    Size=UDim2.new(1,-24,0,20), Position=UDim2.new(0,12,0,50),
    BackgroundTransparency=1, Text="", TextColor3=P.warn,
    Font=EF.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=702, Visible=false,
}, UI.diffViewer)
UI.diffScroll = new("ScrollingFrame", {
    Size=UDim2.new(1,-24,1,-90), Position=UDim2.new(0,12,0,74),
    BackgroundColor3=P.codeBg, BorderSizePixel=0, ScrollBarThickness=6,
    ScrollBarImageColor3=P.border, CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.XY, ZIndex=701,
}, UI.diffViewer)
corner(UI.diffScroll, 10); stroke(UI.diffScroll, P.border, 1)
UI.diffText = new("TextBox", {
    Size=UDim2.new(1,0,0,0), BackgroundTransparency=1, Text="",
    TextColor3=P.codeText, Font=EF.Code, TextSize=12,
    TextWrapped=false, MultiLine=true, TextEditable=false,
    ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, AutomaticSize=Enum.AutomaticSize.XY, ZIndex=702,
}, UI.diffScroll)
pad(UI.diffText, 16, 16, 18, 18)
local DIFF_MAX_LINES = 500
local function splitLines(s)
    local out = {}
    for line in (s.."\n"):gmatch("([^\n]*)\n") do out[#out+1] = line end
    return out
end
local function computeDiff(oldText, newText)
    local a = splitLines(oldText)
    local b = splitLines(newText)
    local n, m = #a, #b
    local truncated = false
    if n > DIFF_MAX_LINES then
        local t = {}
        for k=1,DIFF_MAX_LINES do t[k] = a[k] end
        a = t; n = DIFF_MAX_LINES; truncated = true
    end
    if m > DIFF_MAX_LINES then
        local t = {}
        for k=1,DIFF_MAX_LINES do t[k] = b[k] end
        b = t; m = DIFF_MAX_LINES; truncated = true
    end
    local dp = {}
    for i=0,n do
        dp[i] = {}
        for j=0,m do dp[i][j] = 0 end
    end
    for i=1,n do
        for j=1,m do
            if a[i] == b[j] then dp[i][j] = dp[i-1][j-1] + 1
            else dp[i][j] = math.max(dp[i-1][j], dp[i][j-1]) end
        end
    end
    local result = {}
    local i, j = n, m
    while i > 0 and j > 0 do
        if a[i] == b[j] then
            table.insert(result, 1, {type="same", text=a[i]})
            i = i - 1; j = j - 1
        elseif dp[i-1][j] >= dp[i][j-1] then
            table.insert(result, 1, {type="remove", text=a[i]})
            i = i - 1
        else
            table.insert(result, 1, {type="add", text=b[j]})
            j = j - 1
        end
    end
    while i > 0 do table.insert(result, 1, {type="remove", text=a[i]}); i = i - 1 end
    while j > 0 do table.insert(result, 1, {type="add", text=b[j]}); j = j - 1 end
    return result, truncated
end
S.openDiffViewer = function(title, oldText, newText)
    UI.diffTitle.Text = title or "Diff Viewer"
    local result, truncated = computeDiff(oldText or "", newText or "")
    local out = {}
    local addCount, removeCount, sameCount = 0, 0, 0
    for _,entry in ipairs(result) do
        if entry.type == "add" then
            out[#out+1] = "+ "..entry.text; addCount = addCount + 1
        elseif entry.type == "remove" then
            out[#out+1] = "- "..entry.text; removeCount = removeCount + 1
        else
            out[#out+1] = "  "..entry.text; sameCount = sameCount + 1
        end
    end
    UI.diffText.Text = table.concat(out, "\n")
    UI.diffWarning.Visible = true
    if truncated then
        UI.diffWarning.Text = ("Truncated to %d lines. +%d/-%d/%d unchanged."):format(DIFF_MAX_LINES, addCount, removeCount, sameCount)
    else
        UI.diffWarning.Text = ("+%d added - -%d removed - %d unchanged"):format(addCount, removeCount, sameCount)
    end
    UI.diffViewer.Visible = true
end
UI.diffCloseBtn.MouseButton1Click:Connect(function() UI.diffViewer.Visible = false end)

local chatOrder = 0
local function scrollChatDown()
    task.defer(function()
        task.wait()
        if S.unloaded then return end
        if UI.chatScroll.Parent and UI.chatScroll.Visible then
            UI.chatScroll.CanvasPosition = Vector2.new(0, UI.chatScroll.AbsoluteCanvasSize.Y)
        end
    end)
end
local function parseMD(text)
    text = tostring(text or "")
    local segs, pos = {}, 1
    while true do
        local s, e = text:find("```", pos, true)
        if not s then break end
        local before = text:sub(pos, s-1)
        if before:match("%S") then segs[#segs+1] = {k="text", v=trim(before)} end
        local cs, ce = text:find("```", e+1, true)
        local inner
        if cs then inner = text:sub(e+1, cs-1); pos = ce+1
        else inner = text:sub(e+1); pos = #text+1 end
        local lang, rest = inner:match("^([%w_%+%-]*)[ \t]*\r?\n(.*)$")
        if not lang then lang, rest = "", inner end
        rest = (rest:gsub("\r",""):gsub("\n%s*$",""))
        segs[#segs+1] = {k="code", lang=lang, v=rest}
    end
    local tail = text:sub(pos)
    if tail:match("%S") then segs[#segs+1] = {k="text", v=trim(tail)} end
    if #segs == 0 then segs = {{k="text", v=text}} end
    return segs
end
local function addBubble(text, isUser, fullText)
    local row = new("Frame", {
        Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, LayoutOrder=chatOrder,
    }, UI.chatScroll)
    chatOrder = chatOrder + 1
    new("UIListLayout", {
        HorizontalAlignment=isUser and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
        SortOrder=Enum.SortOrder.LayoutOrder,
    }, row)
    local container = new("Frame", {
        Size=UDim2.new(0,0,0,0), AutomaticSize=Enum.AutomaticSize.XY,
        BackgroundTransparency=1, LayoutOrder=1,
    }, row)
    new("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder}, container)
    local segs = isUser and {{k="text", v=text}} or parseMD(text)
    for i,seg in ipairs(segs) do
        if seg.k == "text" then
            local b = new("Frame", {
                Size=UDim2.new(0,0,0,0), AutomaticSize=Enum.AutomaticSize.XY,
                BackgroundColor3=isUser and P.accent or P.surface1,
                BorderSizePixel=0, LayoutOrder=i,
            }, container)
            corner(b, 14); pad(b, 12, 12, 16, 16)
            local lbl = new("TextLabel", {
                Size=UDim2.new(0,0,0,0), AutomaticSize=Enum.AutomaticSize.XY,
                BackgroundTransparency=1, Text=seg.v,
                TextColor3=isUser and P.textInverse or P.textPrimary,
                Font=EF.Gotham, TextSize=13,
                TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
            }, b)
            new("UISizeConstraint", {MaxSize=Vector2.new(700, math.huge)}, lbl)
        elseif seg.k == "code" then
            local block = new("Frame", {
                Size=UDim2.fromOffset(700,0), AutomaticSize=Enum.AutomaticSize.Y,
                BackgroundColor3=P.codeBg, BorderSizePixel=0, LayoutOrder=i,
            }, container)
            corner(block, 10)
            new("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder}, block)
            local top = new("Frame", {
                Size=UDim2.new(1,0,0,28), BackgroundColor3=P.codeHeader,
                BorderSizePixel=0, LayoutOrder=1,
            }, block)
            corner(top, 10)
            new("TextLabel", {
                Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0,14,0,0),
                BackgroundTransparency=1, Text=seg.lang ~= "" and seg.lang or "lua",
                TextColor3=P.textMuted, Font=EF.GothamBold, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Left,
            }, top)
            local cp = mkButton(top, {
                size=UDim2.fromOffset(58,20), position=UDim2.new(1,-68,0,4),
                text=tr("copy"), textSize=10, radius=5, bg=P.accentTint, textColor=P.accent,
            })
            cp.MouseButton1Click:Connect(function()
                local clip = clipFn()
                if clip then
                    pcall(clip, seg.v)
                    cp.Text = tr("copied")
                    task.delay(1.5, function() cp.Text = tr("copy") end)
                end
            end)
            local tb = new("TextBox", {
                Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
                BackgroundTransparency=1, Text=seg.v, TextColor3=P.codeText,
                Font=EF.Code, TextSize=11, TextWrapped=false,
                MultiLine=true, TextEditable=false, ClearTextOnFocus=false,
                TextXAlignment=Enum.TextXAlignment.Left,
                TextYAlignment=Enum.TextYAlignment.Top, LayoutOrder=2,
            }, block)
            pad(tb, 12, 14, 14, 14)
        end
    end
    if not isUser and fullText then
        local actions = new("Frame", {
            Size=UDim2.fromOffset(280,22), BackgroundTransparency=1, LayoutOrder=#segs+1,
        }, container)
        new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8)}, actions)
        local cpAll = mkButton(actions, {
            size=UDim2.fromOffset(100,22), text="Copy reply", textSize=10, radius=6, layoutOrder=1,
        })
        cpAll.MouseButton1Click:Connect(function()
            local clip = clipFn()
            if clip then
                pcall(clip, fullText)
                cpAll.Text = "Copied!"
                task.delay(1.5, function() cpAll.Text = "Copy reply" end)
            end
        end)
        if #fullText > 800 then
            local viewAll = mkButton(actions, {
                size=UDim2.fromOffset(90,22), text="View full", textSize=10, radius=6, layoutOrder=2,
                bg=P.accentTint, textColor=P.accent,
            })
            viewAll.MouseButton1Click:Connect(function() S.openChatViewer(fullText) end)
        end
    end
    return row
end

local function newConvo()
    local c = {id="c"..os.time().."_"..math.random(1000,9999), title="New chat", messages={}}
    table.insert(S.convos, 1, c)
    S.currentConvoId = c.id
    return c
end
local function getConvo()
    for _,c in ipairs(S.convos) do
        if c.id == S.currentConvoId then return c end
    end
    return nil
end
if #S.convos == 0 then newConvo() else S.currentConvoId = S.convos[1].id end

S.renderConvoList = function()
    if S.unloaded or not UI.convoList then return end
    for _,c in ipairs(UI.convoList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for i,convo in ipairs(S.convos) do
        local active = (convo.id == S.currentConvoId)
        local item = new("Frame", {
            Size=UDim2.new(1,0,0,32),
            BackgroundColor3=active and P.accentTint or P.surface2,
            BorderSizePixel=0, LayoutOrder=i,
        }, UI.convoList)
        corner(item, 7)
        if active then stroke(item, P.accent, 1) end
        local b = new("TextButton", {
            Size=UDim2.new(1,-28,1,0), BackgroundTransparency=1,
            Text=convo.title or "Chat",
            TextColor3=active and P.accent or P.textPrimary,
            Font=EF.GothamMedium, TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd, BorderSizePixel=0,
        }, item)
        pad(b, 0, 0, 10, 0)
        local del = new("TextButton", {
            Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,-24,0.5,-11),
            BackgroundTransparency=1, Text="x", TextColor3=P.textMuted,
            Font=EF.GothamBold, TextSize=11, BorderSizePixel=0,
        }, item)
        b.MouseButton1Click:Connect(function()
            S.currentConvoId = convo.id
            S.renderConvoList(); S.renderChat()
        end)
        del.MouseButton1Click:Connect(function()
            for idx,c in ipairs(S.convos) do
                if c.id == convo.id then table.remove(S.convos, idx); break end
            end
            if S.currentConvoId == convo.id then
                if #S.convos > 0 then S.currentConvoId = S.convos[1].id
                else newConvo() end
            end
            S.saveConvos(); S.renderConvoList(); S.renderChat()
        end)
    end
end
S.renderChat = function()
    if S.unloaded or not UI.chatScroll then return end
    for _,c in ipairs(UI.chatScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    chatOrder = 0
    local convo = getConvo()
    if not convo or #convo.messages == 0 then
        UI.templateContainer.Visible = true
        UI.chatScroll.Visible = false
    else
        UI.templateContainer.Visible = false
        UI.chatScroll.Visible = true
        local startIdx = math.max(1, #convo.messages - DECO.maxConversationMsgsRendered + 1)
        for i=startIdx,#convo.messages do
            local m = convo.messages[i]
            addBubble(m.t, m.r == "user", m.r == "ai" and m.t or nil)
        end
        scrollChatDown()
    end
end
UI.newConvoBtn.MouseButton1Click:Connect(function()
    newConvo()
    S.saveConvos()
    S.renderConvoList()
    S.renderChat()
end)
UI.chatExplainBtn.MouseButton1Click:Connect(function()
    local txt = trim(UI.chatInput.Text)
    if txt == "" then S.showToast(tr("enter_text_explain"), "warn"); return end
    local lower = txt:lower()
    local payload = txt
    if not lower:match("^%s*explain") then
        payload = "Explain the following code or text. Describe its purpose, main operations, risks. Do not execute. Provide a clear explanation:\n"..txt
    end
    S.sendMsg(payload, {display=txt})
end)

S.sendMsg = function(text, opts)
    local sendText = trim(tostring(text or ""))
    local displayText = sendText
    if opts and opts.display then displayText = trim(tostring(opts.display or "")) end
    if sendText == "" or S.unloaded then return end
    if S.busy then S.showToast(tr("wait_current_reply"), "warn"); return end
    local apiKey = getCurrentApiKey()
    if apiKey == "" then
        S.showToast(tr("set_api_key"), "warn")
        S.switchView("cfg")
        return
    end
    local convo = getConvo()
    if not convo then convo = newConvo(); S.renderConvoList() end
    S.busy = true
    pcall(function()
        if UI.chatSendBtn then UI.chatSendBtn.Text = "..." end
        if UI.chatSendBtn then paintButton(UI.chatSendBtn, P.accentSoft, P.textInverse) end
        if UI.chatInput then UI.chatInput.Text = "" end
        if UI.templateContainer then UI.templateContainer.Visible = false end
        if UI.chatScroll then UI.chatScroll.Visible = true end
    end)
    addBubble(displayText, true)
    convo.messages[#convo.messages+1] = {r="user", t=displayText}
    if #convo.messages == 1 then
        convo.title = cut(displayText, 28)
        S.renderConvoList()
    end
    scrollChatDown()
    S.saveConvos()
    local placeholder = addBubble("...", false)
    scrollChatDown()
    local watchToken = genId("aiwatch")
    S._lastAIWatch = watchToken
    trackTask(task.spawn(function()
        local history = {}
        local start = #convo.messages - 15
        if start < 1 then start = 1 end
        for i=start,#convo.messages do history[#history+1] = convo.messages[i] end
        local ctx = buildCtx(sendText)
        local sysPrompt = SYS_PROMPT
        if ctx ~= "" then sysPrompt = sysPrompt.."\n"..ctx end
        local okCall, result, err2 = pcall(askAI, history, sendText, sysPrompt)
        local answer, err
        if not okCall then answer, err = nil, tostring(result)
        else answer, err = result, err2 end
        if placeholder then pcall(function() if placeholder.Parent then placeholder:Destroy() end end) end
        if S.unloaded then
            S.busy = false
            if S._lastAIWatch == watchToken then S._lastAIWatch = nil end
            return
        end
        local isStale = (S._lastAIWatch ~= watchToken)
        if isStale then
            S.log("WARN", "ai", "Late reply ignored")
            S.saveConvos(); S.updateDash()
            return
        end
        if answer then
            addBubble(answer, false, answer)
            convo.messages[#convo.messages+1] = {r="ai", t=answer}
            S.log("SUCCESS", "ai", "Reply "..#answer.." chars")
            S.kbAddAnalysis(sendText, answer, {})
            if CFG.aiMemoryEnabled and CFG.aiMemoryAutoLearn then
                aiMemoryAdd("conversations", "topic_"..os.time(), cut(sendText, 100))
            end
        else
            addBubble("Error: "..tostring(err), false)
            S.log("ERROR", "ai", tostring(err))
        end
        S.saveConvos(); scrollChatDown(); S.updateDash()
        S.busy = false
        if S._lastAIWatch == watchToken then S._lastAIWatch = nil end
        if UI.chatSendBtn then
            pcall(function() UI.chatSendBtn.Text = "->" end)
            pcall(function() paintButton(UI.chatSendBtn, P.accent, P.textInverse) end)
        end
    end))
    task.delay(CFG.httpTimeout + 5, function()
        if S.unloaded then return end
        if S._lastAIWatch == watchToken and S.busy then
            if placeholder then pcall(function() if placeholder.Parent then placeholder:Destroy() end end) end
            S.busy = false
            S._lastAIWatch = nil
            pcall(function()
                if UI.chatSendBtn then
                    UI.chatSendBtn.Text = "->"
                    paintButton(UI.chatSendBtn, P.accent, P.textInverse)
                end
            end)
            S.showToast(tr("ai_timed_out"), "warn")
        end
    end)
end
UI.chatSendBtn.MouseButton1Click:Connect(function() S.sendMsg(UI.chatInput.Text) end)
UI.chatInput.FocusLost:Connect(function(enter) if enter then S.sendMsg(UI.chatInput.Text) end end)

S.refreshLocale = function()
    if S.unloaded then return end
    pcall(function()
        if UI.headerLabel then
            local h = tr_view(S.currentView, 1)
            if h and h ~= "" then UI.headerLabel.Text = h end
        end
        if UI.headerSubtitle then
            local hs = tr_view(S.currentView, 2)
            if hs and hs ~= "" then UI.headerSubtitle.Text = hs end
        end
        if UI.convoSideTitle then UI.convoSideTitle.Text = tr("conversations") end
        if UI.newConvoBtn then UI.newConvoBtn.Text = tr("new_chat") end
        if UI.chatInput then UI.chatInput.PlaceholderText = tr("chat_placeholder") end
        if UI.tplTitle then UI.tplTitle.Text = tr("tpl_new") end
        if UI.tplSaveBtn then UI.tplSaveBtn.Text = tr("save") end
        if UI.tplDeleteBtn then UI.tplDeleteBtn.Text = tr("delete") end
        if UI.dashRefreshBtn then UI.dashRefreshBtn.Text = tr("refresh") end
        if UI.scanRunBtn then UI.scanRunBtn.Text = tr("scan_game") end
        if UI.scanCopyBtn then UI.scanCopyBtn.Text = tr("copy_report") end
        if UI.scanSaveBtn then UI.scanSaveBtn.Text = tr("save_txt") end
        if UI.dumpScanBtn then UI.dumpScanBtn.Text = tr("scan_scripts") end
        if UI.dumpCopyBtn then UI.dumpCopyBtn.Text = tr("copy_paths") end
        if UI.dumpFilterBtn then UI.dumpFilterBtn.Text = tr("all") end
        if UI.decAllBtn then UI.decAllBtn.Text = tr("decompile_all") end
        if UI.decCopyBtn then UI.decCopyBtn.Text = tr("copy") end
        if UI.decRunBtn then UI.decRunBtn.Text = tr("run_code") end
        if UI.spyToggle then UI.spyToggle.Text = (S.spyHooked and tr("stop") or tr("start")) end
        if UI.spyClearBtn then UI.spyClearBtn.Text = tr("clear") end
        if UI.spyCopyBtn then UI.spyCopyBtn.Text = tr("copy") end
        if UI.spySendBtn then UI.spySendBtn.Text = tr("send_ai") end
        if UI.patternsRunBtn then UI.patternsRunBtn.Text = tr("run_detection") end
        if UI.searchRunBtn then UI.searchRunBtn.Text = tr("search") end
        if UI.worldRefreshBtn then UI.worldRefreshBtn.Text = tr("refresh") end
        if UI.logsClearBtn then UI.logsClearBtn.Text = tr("clear") end
        if UI.logsCopyBtn then UI.logsCopyBtn.Text = tr("copy_all") end
        if UI.safeStopBtn then UI.safeStopBtn.Text = tr("stop_all_tasks") end
        if UI.safeUnloadBtn then UI.safeUnloadBtn.Text = tr("unload") end
        if UI.memoryAddBtn then UI.memoryAddBtn.Text = tr("memory_add") end
        if UI.memoryClearBtn then UI.memoryClearBtn.Text = tr("memory_clear") end
        for k,nav in pairs(UI.navButtons) do
            pcall(function() nav.label.Text = tr_view(k, 1) end)
        end
    end)
end

for key,nav in pairs(UI.navButtons) do
    nav.frame.MouseButton1Click:Connect(function() S.switchView(key) end)
end

track(UIS.InputBegan:Connect(function(input, gp)
    if S.unloaded then return end
    if input.KeyCode == S.toggleKey then
        setGuiVisible(not S.guiVisible)
        return
    end
    if gp then return end
end))

track(RS.RenderStepped:Connect(function(dt)
    if S.unloaded then return end
    updateFpsBuffer(dt)
end))

trackTask(task.spawn(function()
    while not S.unloaded do
        task.wait(0.5)
        if S.unloaded then break end
        pcall(function()
            if S.currentView ~= "spy" or not S.spyHooked then return end
            if not UI.spyList then return end
            local last = S._spyLastShown or 0
            if #S.remotes ~= last then
                S._spyLastShown = #S.remotes
                for _,c in ipairs(UI.spyList:GetChildren()) do
                    if c:IsA("Frame") or c:IsA("TextLabel") then pcall(function() c:Destroy() end) end
                end
                if UI.spyStatus then UI.spyStatus.Text = string.format(tr("spy_calls"), #S.remotes) end
                for i,l in ipairs(S.remotes) do
                    if i > 60 then break end
                    pcall(function()
                        new("TextLabel", {
                            Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
                            Text="["..l.method.."] "..l.name.." ("..l.args..")",
                            TextColor3=P.textPrimary, Font=EF.Code, TextSize=10,
                            TextXAlignment=Enum.TextXAlignment.Left,
                            TextTruncate=Enum.TextTruncate.AtEnd, LayoutOrder=i,
                        }, UI.spyList)
                    end)
                end
            end
        end)
    end
end))

trackTask(task.spawn(function()
    while not S.unloaded do
        task.wait(3)
        if S.unloaded then break end
        if S.currentView == "dash" then pcall(S.updateDash) end
        if S.currentView == "safe" and S.updateSafety then pcall(S.updateSafety) end
    end
end))

trackTask(task.spawn(function()
    while not S.unloaded do
        task.wait(5)
        if S.unloaded then break end
        pcall(kbFlushIfDirty)
    end
end))

trackTask(task.spawn(function()
    while not S.unloaded do
        task.wait(60)
        if S.unloaded then break end
        local alive = {}
        for _,t in ipairs(S.tasks) do
            if not isTaskDead(t) then alive[#alive+1] = t end
        end
        S.tasks = alive
    end
end))

local function unload()
    if S.unloaded then return end
    S.unloaded = true
    S.log("INFO", "core", "Unloading...")
    if CFG.saveOnUnload then
        local ok = S.saveConvosNow()
        if ok then S.log("INFO", "core", "Conversations saved") end
    end
    for k,_ in pairs(KB) do pcall(kbFlushNow, k) end
    pcall(S.kbSaveSession)
    pcall(saveAiMemory)
    pcall(saveInstalledScripts)
    pcall(saveDebuggerLog)
    S.spyHooked = false
    if S.oldNamecall and S.oldSpyOwner == "SonicAI" then
        pcall(function() hookmetamethod(game, "__namecall", S.oldNamecall) end)
    end
    S.oldNamecall = nil; S.oldSpyOwner = nil
    for _,c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    S.conns = {}
    task.wait(0.1)
    for _,t in ipairs(S.tasks) do pcall(function() task.cancel(t) end) end
    S.tasks = {}
    task.wait(0.05)
    pcall(function() if UI.gui and UI.gui.Parent then UI.gui:Destroy() end end)
    pcall(function()
        local g = getgenv and getgenv()
        if type(g)=="table" and g.SonicAIUnload == unload then g.SonicAIUnload = nil end
    end)
    S.log("INFO", "core", "Unloaded")
end

pcall(function()
    local g = getgenv and getgenv()
    if type(g)=="table" then g.SonicAIUnload = unload end
end)
UI.closeBtn.MouseButton1Click:Connect(function() setGuiVisible(false) end)
UI.safeUnloadBtn.MouseButton1Click:Connect(unload)

S.sessionStartedAt = os.time()
S.sessionOk = 0
S.sessionPartial = 0
S.sessionFail = 0
S._decompiledSinceSave = 0
print("[SAI] Boot phase: session init done")
fetchGameName()
S.switchView("dash")
S.updateDash()
S.renderConvoList()
S.renderChat()
S.renderLogs()
S.renderWorld()
S.renderDump()
S.renderPatterns()
S.updateDecStatus()
if S.renderSnapshots then S.renderSnapshots() end
if S.renderMemory then S.renderMemory() end
if S.renderMarketplace then S.renderMarketplace() end
if S.renderDebugger then S.renderDebugger() end
print("[SAI] Boot phase: views rendered")

if CFG.autoScan then
    trackTask(task.delay(1.5, function()
        if not S.unloaded then S.scanGame() end
    end))
end
if CFG.autoSpy then
    trackTask(task.delay(2.5, function()
        if not S.unloaded then S.startSpy() end
    end))
end

S.log("SUCCESS", "core", "Sonic AI v13.0 FIXED READY")

trackTask(task.delay(3, function()
    if not S.unloaded then S.showToast(tr("ready_message"), "success") end
end))

end  -- ⬅️ FIN DU DO BLOCK

print("=== SONIC AI v13.0 READY ===")
