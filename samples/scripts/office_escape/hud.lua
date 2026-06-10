local M = {}
local stress = 0

function M.draw()
    -- Draw background bar
    cpp_draw_rect(10, 10, 200, 20, 50, 50, 50, 200)
    -- Draw stress fill
    local fill_w = (stress / 100) * 200
    cpp_draw_rect(10, 10, fill_w, 20, 200, 50, 50, 255)
    cpp_draw_text_left("STRESS: " .. math.floor(stress) .. "%", 15, 10, 16, 255, 255, 255)
end

function M.addStress(v) 
    stress = math.min(100, math.max(0, stress + v)) 
end

function M.getStress() return stress end

return M
