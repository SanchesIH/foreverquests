local _, ns = ...

-- Builds a layered (BtWQuests-like, top -> bottom) layout for one chain.
-- Returns { nodes = { {key, quest=id | link=info, layer, pos} }, edges = { {fromKey, toKey, type} },
--           layers = { [layer] = {keys...} }, hiddenHigher = n }

local function addEdge(list, seen, a, b, t)
    local k = a .. ">" .. b
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { a, b, t }
end

function ns.BuildChainLayout(cid, forceAll)
    local c = ns.C[cid]
    local members = c[3]
    local flat = c[4] or {}

    local succ = {}
    for i = 1, #flat, 3 do
        local a, b, t = flat[i], flat[i + 1], flat[i + 2]
        succ[a] = succ[a] or {}
        table.insert(succ[a], { b, t })
    end

    local visible, eligible = {}, {}
    local hiddenHigher = 0
    for _, id in ipairs(members) do
        if ns.IsEligible(id) then
            eligible[id] = true
            if forceAll or ns.PassesLevel(id) then
                visible[id] = true
            else
                hiddenHigher = hiddenHigher + 1
            end
        end
    end

    local nodes, byKey, edges, seenEdge = {}, {}, {}, {}
    local function node(key, data)
        if byKey[key] then return byKey[key] end
        data.key = key
        nodes[#nodes + 1] = data
        byKey[key] = data
        return data
    end

    for _, id in ipairs(members) do
        if visible[id] then node(id, { quest = id }) end
    end

    -- edges between visible quests, bridging hidden ones (other race/class, above level)
    for _, a in ipairs(members) do
        if visible[a] then
            local stack, seen = {}, {}
            for _, e in ipairs(succ[a] or {}) do stack[#stack + 1] = { e[1], e[2] } end
            while #stack > 0 do
                local top = table.remove(stack)
                local b, t = top[1], top[2]
                if not seen[b] then
                    seen[b] = true
                    if visible[b] then
                        addEdge(edges, seenEdge, a, b, t)
                    elseif byKey[b] == nil then
                        for _, e in ipairs(succ[b] or {}) do stack[#stack + 1] = { e[1], t } end
                    end
                end
            end
        end
    end

    -- cross-map links
    local outs, ins = c[5], c[6]
    if outs then
        for i = 1, #outs, 3 do
            local a, b, t = outs[i], outs[i + 1], outs[i + 2]
            if visible[a] and ns.IsEligible(b) then
                local q = ns.Q[b]
                local key = "o:" .. a .. ":" .. (q[ns.F.CHAIN] or b)
                local n = node(key, { link = { dir = "out", quest = b, cat = q[ns.F.CAT], chain = q[ns.F.CHAIN], type = t } })
                addEdge(edges, seenEdge, a, key, t)
                n.link.quests = n.link.quests or {}
                table.insert(n.link.quests, b)
            end
        end
    end
    if ins then
        for i = 1, #ins, 3 do
            local a, b, t = ins[i], ins[i + 1], ins[i + 2]
            if visible[b] and ns.IsEligible(a) then
                local q = ns.Q[a]
                local key = "i:" .. (q[ns.F.CHAIN] or a)
                local n = node(key, { link = { dir = "in", quest = a, cat = q[ns.F.CAT], chain = q[ns.F.CHAIN], type = t } })
                addEdge(edges, seenEdge, key, b, t)
                n.link.quests = n.link.quests or {}
                n.link.seen = n.link.seen or {}
                if not n.link.seen[a] then
                    n.link.seen[a] = true
                    table.insert(n.link.quests, a)
                end
            end
        end
    end

    -- "Go to <NPC>": every way into the chain starts with the person (or object, or item) who
    -- hands out its first quest, the way BtWQuests shows it. Entry quests sharing a giver share
    -- one node.
    do
        local hasIn = {}
        for _, e in ipairs(edges) do hasIn[e[2]] = true end
        local roots = {}
        for _, n in ipairs(nodes) do
            if n.quest and not hasIn[n.key] then roots[#roots + 1] = n end
        end
        for _, n in ipairs(roots) do
            local q = ns.Q[n.quest]
            local kind, eid = q[9], q[10]
            if kind and eid then
                local key = "g:" .. kind .. ":" .. eid
                local g = node(key, { giver = { kind = kind, id = eid, map = q[11], x = q[12], y = q[13], quests = {} } })
                table.insert(g.giver.quests, n.quest)
                addEdge(edges, seenEdge, key, n.key, 2)
            end
        end
    end

    -- adjacency for layering
    local out, inn = {}, {}
    for _, n in ipairs(nodes) do out[n.key], inn[n.key] = {}, {} end
    for _, e in ipairs(edges) do
        table.insert(out[e[1]], e[2])
        table.insert(inn[e[2]], e[1])
    end

    -- break cycles with DFS (drop back edges)
    local color, back = {}, {}
    local function dfs(k)
        color[k] = 1
        for _, v in ipairs(out[k]) do
            if color[v] == 1 then
                back[k .. ">" .. v] = true
            elseif not color[v] then
                dfs(v)
            end
        end
        color[k] = 2
    end
    for _, n in ipairs(nodes) do if not color[n.key] then dfs(n.key) end end
    if next(back) then
        local kept = {}
        for _, e in ipairs(edges) do
            if not back[e[1] .. ">" .. e[2]] then kept[#kept + 1] = e end
        end
        edges = kept
        for _, n in ipairs(nodes) do out[n.key], inn[n.key] = {}, {} end
        for _, e in ipairs(edges) do
            table.insert(out[e[1]], e[2])
            table.insert(inn[e[2]], e[1])
        end
    end

    -- longest-path layering
    local layer = {}
    local function L(k, guard)
        if layer[k] then return layer[k] end
        guard = (guard or 0) + 1
        if guard > 400 then return 0 end
        local best = 0
        for _, p in ipairs(inn[k]) do
            local v = L(p, guard) + 1
            if v > best then best = v end
        end
        layer[k] = best
        return best
    end
    for _, n in ipairs(nodes) do n.layer = L(n.key) end

    -- incoming links sit directly above their target; pull roots down next to their child
    for _, n in ipairs(nodes) do
        if #inn[n.key] == 0 and #out[n.key] > 0 then
            local minChild
            for _, v in ipairs(out[n.key]) do
                local lv = byKey[v].layer
                if not minChild or lv < minChild then minChild = lv end
            end
            if minChild and minChild - 1 > n.layer then n.layer = minChild - 1 end
        end
    end

    -- group into layers, initial order by level then id
    local layers, maxLayer = {}, 0
    for _, n in ipairs(nodes) do
        layers[n.layer] = layers[n.layer] or {}
        table.insert(layers[n.layer], n)
        if n.layer > maxLayer then maxLayer = n.layer end
    end
    local function sortKey(n)
        if n.quest then
            local q = ns.Q[n.quest]
            return (q[ns.F.REQ] or 0) * 100000 + n.quest
        end
        return 99 * 100000
    end
    for i = 0, maxLayer do
        layers[i] = layers[i] or {}
        table.sort(layers[i], function(a, b) return sortKey(a) < sortKey(b) end)
        for p, n in ipairs(layers[i]) do n.pos = p end
    end

    -- barycenter ordering sweeps
    local function sweep(down)
        local from, to, step = 1, maxLayer, 1
        if not down then from, to, step = maxLayer - 1, 0, -1 end
        for i = from, to, step do
            local row = layers[i]
            for _, n in ipairs(row) do
                local nb = down and inn[n.key] or out[n.key]
                local sum, cnt = 0, 0
                for _, k in ipairs(nb) do
                    local m = byKey[k]
                    if m and m.layer == i - step then
                        sum = sum + m.pos
                        cnt = cnt + 1
                    end
                end
                n.bary = cnt > 0 and (sum / cnt) or n.pos
            end
            table.sort(row, function(a, b)
                if a.bary ~= b.bary then return a.bary < b.bary end
                return sortKey(a) < sortKey(b)
            end)
            for p, n in ipairs(row) do n.pos = p end
        end
    end
    for _ = 1, 3 do
        sweep(true)
        sweep(false)
    end

    local width = 0
    for i = 0, maxLayer do
        if #layers[i] > width then width = #layers[i] end
    end

    return {
        nodes = nodes, byKey = byKey, edges = edges, layers = layers,
        depth = maxLayer, width = width, hiddenHigher = hiddenHigher,
    }
end

--- A standalone quest drawn like a chain of one: who gives it, then the quest.
function ns.BuildSingleLayout(id)
    local q = ns.Q[id]
    local qn = { key = id, quest = id, layer = 0, pos = 1 }
    local nodes, edges, layers = { qn }, {}, { [0] = { qn } }
    if q[9] and q[10] then
        local g = { key = "g:" .. q[9] .. ":" .. q[10], layer = 0, pos = 1,
            giver = { kind = q[9], id = q[10], map = q[11], x = q[12], y = q[13], quests = { id } } }
        qn.layer = 1
        nodes = { g, qn }
        edges = { { g.key, id, 2 } }
        layers = { [0] = { g }, [1] = { qn } }
    end
    local byKey = {}
    for _, n in ipairs(nodes) do byKey[n.key] = n end
    return { nodes = nodes, byKey = byKey, edges = edges, layers = layers, depth = #nodes - 1, width = 1, hiddenHigher = 0 }
end
