# tests/test_helpers.nim
# Shared in-process CLI execution & stdout/stderr capture utilities for Garden tests.

import std/[os, strutils]
when defined(posix):
  import std/posix
elif defined(windows):
  proc c_dup(fd: cint): cint {.importc: "_dup", header: "<io.h>".}
  proc c_dup2(fd1, fd2: cint): cint {.importc: "_dup2", header: "<io.h>".}
  proc c_close(fd: cint): cint {.importc: "_close", header: "<io.h>".}
import ../src/update
import ../src/garden

putEnv("RHIZO_EAR_DISABLED", "1")
putEnv("RHIZO_TEST", "1")

var ioCaptureSeq = 0

proc captureIo*(body: proc ()): tuple[output: string, exitCode: int] =
  inc ioCaptureSeq
  let tmpPath = getTempDir() / ("garden_io_" & $getCurrentProcessId() & "_" & $ioCaptureSeq & ".tmp")
  var exitCode = 0
  when defined(posix):
    flushFile(stdout)
    flushFile(stderr)
    let savedOut = dup(STDOUT_FILENO)
    let savedErr = dup(STDERR_FILENO)
    let f = open(tmpPath, fmReadWrite)
    let fd = getFileHandle(f)
    discard fcntl(fd, F_SETFD, FD_CLOEXEC)
    discard fcntl(savedOut, F_SETFD, FD_CLOEXEC)
    discard fcntl(savedErr, F_SETFD, FD_CLOEXEC)
    discard dup2(fd, STDOUT_FILENO)
    discard dup2(fd, STDERR_FILENO)
    try:
      body()
    except CliExitError as e:
      exitCode = e.exitCode
    finally:
      flushFile(stdout)
      flushFile(stderr)
      discard dup2(savedOut, STDOUT_FILENO)
      discard dup2(savedErr, STDERR_FILENO)
      discard close(savedOut)
      discard close(savedErr)
      f.close()
  elif defined(windows):
    flushFile(stdout)
    flushFile(stderr)
    let savedOut = c_dup(1)
    let savedErr = c_dup(2)
    let f = open(tmpPath, fmReadWrite)
    let fd = cint(getFileHandle(f))
    discard c_dup2(fd, 1)
    discard c_dup2(fd, 2)
    try:
      body()
    except CliExitError as e:
      exitCode = e.exitCode
    finally:
      flushFile(stdout)
      flushFile(stderr)
      discard c_dup2(savedOut, 1)
      discard c_dup2(savedErr, 2)
      discard c_close(savedOut)
      discard c_close(savedErr)
      f.close()
  else:
    try:
      body()
    except CliExitError as e:
      exitCode = e.exitCode
  var captured = ""
  if fileExists(tmpPath):
    captured = readFile(tmpPath)
    try: removeFile(tmpPath) except CatchableError: discard
  return (captured, exitCode)

proc captureRet*(body: proc (): int): tuple[output: string, exitCode: int] =
  var retCode = 0
  let (captured, quitCode) = captureIo(proc () =
    retCode = body()
  )
  let effectiveCode = if quitCode != 0: quitCode else: retCode
  return (captured, effectiveCode)

proc runGardenInProcess*(args: openArray[string]): tuple[output: string, exitCode: int] =
  let argSeq = @args
  return captureIo(proc () =
    main(argSeq, useCustomParams = true)
  )
