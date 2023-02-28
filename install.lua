local runningProgram = shell.get
local programName = fs.getName(runningProgram)
local CWD = runningProgram:sub(1, #runningProgram - #programName )
def_file = string.format("%s/requirements/definitions", {CWD})
print(def_file)
fs.move()