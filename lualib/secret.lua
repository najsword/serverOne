local crypt = require "skynet_crypt"

local secret ={}

function secret.make_key()
    local random_key = crypt.randomkey()
    return crypt.base64encode(crypt.dhexchange(random_key))
end

return secret