## Types for extension state, this should either get fleshed out or removed
import std/[options, times, strutils, jsconsole, tables]
import platform/vscodeApi

from platform/languageClientApi import VscodeLanguageClient

type
  Backend* = cstring
  Timestamp* = cint
  NimsuggestId* = cstring

  PendingRequestState* = enum
    prsOnGoing = "OnGoing"
    prsCancelled = "Cancelled"
    prsComplete = "Complete"

  PendingRequestStatus* = object
    name*: cstring
    projectFile*: cstring
    time*: cstring
    state*: cstring

  NimSuggestStatus* = object
    projectFile*: cstring
    capabilities*: seq[cstring]
    version*: cstring
    path*: cstring
    port*: int32
    openFiles*: seq[cstring]
    unknownFiles*: seq[cstring]

  ProjectError* = object
    projectFile*: cstring
    errorMessage*: cstring
    lastKnownCmd*: cstring

  NimLangServerStatus* = object
    version*: cstring
    lspPath*: cstring
    nimsuggestInstances*: seq[NimSuggestStatus]
    openFiles*: seq[cstring]
    extensionCapabilities*: seq[cstring]
    pendingRequests*: seq[PendingRequestStatus]
    projectErrors*: seq[ProjectError]

  LspItem* = ref object of TreeItem
    instance*: Option[NimSuggestStatus]
    notification*: Option[Notification]

  Notification* = object
    message*: cstring
    kind*: cstring
    id*: cstring
    date*: DateTime

  NimLangServerStatusProvider* = ref object of JsObject
    status*: Option[NimLangServerStatus]
    notifications*: seq[Notification]
    lastId*: int32 # onDidChangeTreeData*: EventEmitter

  LSPVersion* = tuple[major: int, minor: int, patch: int]

  NimbleTask* = object
    name*: cstring
    description*: cstring
    isRunning*: bool
  
  RunTaskParams* = object
    command*: seq[cstring] #command and args
  
  RunTaskResult* = object
    command*: seq[cstring] #command and args
    output*: seq[cstring] #output lines

  LspExtensionCapability* = enum #List of extensions the lsp server support.
    excNone = "None"
    excRestartSuggest = "RestartSuggest"
    excNimbleTask = "NimbleTask"
        
  ExtensionState* = ref object
    ctx*: VscodeExtensionContext
    config*: VscodeWorkspaceConfiguration
    channel*: VscodeOutputChannel
    lspChannel*: VscodeOutputChannel
    client*: VscodeLanguageClient
    installPerformed*: bool
    nimDir*: string
      # Nim used directory. Extracted on activation from nimble. When it's "", means nim in the PATH is used.
    statusProvider*: NimLangServerStatusProvider
    lspVersion*: LSPVersion
    lspExtensionCapabilities*: set[LspExtensionCapability]
    nimbleTasks*: seq[NimbleTask]
    propagatedDecorations*: Table[cstring, seq[VscodeTextEditorDecorationType]]
    
   

# type
#   SolutionKind* {.pure.} = enum
#     skSingleFile, skFolder, skWorkspace

#   NimsuggestProcess* = ref object
#     process*: ChildProcess
#     rpc*: EPCPeer
#     startingPath*: cstring
#     projectPath*: cstring
#     backend*: Backend
#     nimble*: VscodeUri
#     updateTime*: Timestamp

#   ProjectKind* {.pure.} = enum
#     pkNim, pkNims, pkNimble

#   ProjectSource* {.pure.} = enum
#     psDetected, psUserDefined

#   Project* = ref object
#     uri*: VscodeUri
#     source*: ProjectSource
#     nimsuggest*: NimsuggestId
#     hasNimble*: bool
#     matchesNimble*: bool
#     case kind*: ProjectKind
#     of pkNim:
#       hasCfg*: bool
#       hasNims*: bool
#     of pkNims, pkNimble: discard

#   ProjectCandidateKind* {.pure.} = enum
#     pckNim, pckNims, pckNimble

#   ProjectCandidate* = ref object
#     uri*: VscodeUri
#     kind*: ProjectCandidateKind

proc getNimCmd*(state: ExtensionState): cstring =
  if state.nimDir == "":
    "nim ".cstring
  else:
    (state.nimDir & "/nim ").cstring

proc getTaskByName*(state: ExtensionState, name: cstring): Option[NimbleTask] =
  for task in state.nimbleTasks:
    if task.name == name:
      return some task
  none(NimbleTask)

proc markTaskAsRunning*(state: ExtensionState, name: cstring, isRunning: bool) =
  for task in state.nimbleTasks.mitems:
    if task.name == name:
      task.isRunning = isRunning
      break

proc addExtensionCapabilities*(state: ExtensionState, caps: seq[cstring]) =
  for cap in caps:
    try:
      let extCap = parseEnum[LspExtensionCapability]($cap)
      state.lspExtensionCapabilities.incl extCap
    except ValueError:
      console.error(("Error parsing server extension capability " & cap))
  # outputLine(fmt" Lsp Server Extension Capabilities: {state.lspExtensionCapabilities}".cstring)

proc fetchLsp*[T, U](
    state: ExtensionState, name: string, params: U
): Future[T] {.async.} =
  console.log("[FetchLsp] ", name, params.toJs())
  let response = await state.client.sendRequest(name, params.toJs())
  let res = jsonStringify(response).jsonParse(T)
  console.log(res)
  return res

proc fetchLsp*[T](state: ExtensionState, name: string): Future[T] =
  return fetchLsp[T, JsObject](state, name, ().toJs())

