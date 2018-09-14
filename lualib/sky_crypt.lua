local crypt = require "skynet_crypt"

local sky_crypt ={}

function sky_crypt.make_random()
    return crypt.randomkey()
end

function sky_crypt.dhexchange(key)
    return crypt.dhexchange(key)
end

function sky_crypt.base64encode(key)
    return crypt.base64encode(key)
end

function sky_crypt.base64decode(key)
    return crypt.base64decode(key)
end

--用key加密plaintext得到密文，key必须是8字节
function sky_crypt.desencode(key, plaintext)
    return crypt.desencode(key, plaintext)
end

--用key解密ciphertext得到明文，key必须是8字节
function sky_crypt.desdecode(key, ciphertext)
    return crypt.desdecode(key, ciphertext)
end

function sky_crypt.hexencode(key)
    return crypt.hexencode(key)
end

function sky_crypt.hexdecode(key)
    return crypt.hexdecode(key)
end

function sky_crypt.dhsecret(ckey, skey) 
    return crypt.dhsecret(ckey, skey) 
end

--HMAC64运算利用哈希算法，以一个密钥secret和一个消息challenge为输入，生成一个消息摘要hmac作为输出。
function sky_crypt.hmac64(challenge, secret)
    return crypt.hmac64(challenge, secret)
end

--云风自实现的hash算法，只能哈希小于8字节的数据，返回8字节数据的hash
function sky_crypt.hashkey(str)
    return crypt.hashkey(str)
end

return sky_crypt