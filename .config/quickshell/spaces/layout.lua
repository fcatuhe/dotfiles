spaces_hidden = spaces_hidden or {}
spaces_rank = spaces_rank or {}

local function order(target)
  local window = target.window
  if not window then
    return math.huge
  end
  return (spaces_rank[window.address] or 1000) * 1e10 + window.stable_id
end

local function place(ctx, targets, area, index)
  if index > #targets then
    return
  end
  if index == #targets then
    targets[index]:place(area)
    return
  end
  local wide = area.w >= area.h
  targets[index]:place(ctx:split(area, wide and "left" or "top", 0.5))
  place(ctx, targets, ctx:split(area, wide and "right" or "bottom", 0.5), index + 1)
end

if not spaces_layout_registered then
  spaces_layout_registered = true

  hl.layout.register("spaces", {
    recalculate = function(ctx)
      local shown = {}
      for _, target in ipairs(ctx.targets) do
        if target.window and spaces_hidden[target.window.address] then
          target:set_box({ x = -100000, y = -100000, w = ctx.area.w, h = ctx.area.h })
        else
          table.insert(shown, target)
        end
      end
      table.sort(shown, function(left, right) return order(left) < order(right) end)
      place(ctx, shown, ctx.area, 1)
    end,

    layout_msg = function() end,
  })
end
