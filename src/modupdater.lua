local ui, uiu, uie = require("ui").quick()
local utils = require("utils")
local threader = require("threader")
local alert = require("alert")
local config = require("config")
local sharp = require("sharp")
local fs = require("fs")

local modupdater = {}

function modupdater.updateAllMods(path, notify, mode, callback)
    local willRunGame = callback == nil

    local origMode = mode
    local origCallback = mode

    mode = mode or config.updateModsOnStartup
    callback = callback or function()
        utils.launch(nil, false, notify)
    end

    if mode == "none" then
        callback()
        return
    end

    local task = sharp.updateAllMods(path or config.installs[config.install].path, mode == "enabled"):result()

    local alertMessage = alert({
        title = mode == "enabled" and "Updating enabled mods" or "Updating all mods",
        body = uie.column({
            uie.row({
                uie.spinner():with({
                    width = 16,
                    height = 16
                }),
                uie.label("Please wait..."):as("loadingMessage")
            })
        }):with(uiu.fillWidth),
        buttons = {
            {
                willRunGame and "Skip" or "Cancel",
                function(container)
                    sharp.free(task)
                    callback()
                    container:close()
                end
            }
        },
        init = function(container)
            container:findChild("box"):with({
                width = 600, height = 120
            })
            container:findChild("buttons"):with(uiu.bottombound)
        end
    })

    alertMessage:findChild("bg"):hook({
        onClick = function() end
    })

    threader.routine(function()
        local status
        repeat
            status = sharp.pollWait(task, true):result() or { "interrupted", "", "" }
            local lastStatusLine = status[3]

            if lastStatusLine then
                alertMessage:findChild("loadingMessage"):setText(lastStatusLine)
            end
        until status[1] ~= "running"

        alertMessage:close()

        if status[1] == "done" then
            callback()
        elseif status[1] ~= "interrupted" then
            local buttons = {
                {
                    "Retry",
                    function(container)
                        modupdater.updateAllMods(path, notify, origMode, origCallback)
                        container:close()
                    end
                },
                {
                    "Open logs folder",
                    function(container)
                        utils.openFile(fs.getStorageDir())
                    end
                },
                {
                    willRunGame and "Run anyway" or "Cancel",
                    function(container)
                        callback()
                        container:close()
                    end
                }
            }

            if willRunGame then
                table.insert(buttons,
                {
                    "Cancel",
                    function(container)
                        container:close()
                    end
                })
            end

            alert({
                body = "An error occurred while updating your mods.\nMake sure you are connected to the Internet and that Lönn is not running!",
                buttons = buttons
            })
        end
    end)
end

return modupdater