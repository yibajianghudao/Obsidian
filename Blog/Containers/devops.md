
这是 DevOps基础与实践-马腾飞 这本书的学习笔记

书中共有6台虚拟机,但由于我的电脑配置比较低(24线程32G),我对一些配置进行了修改:

master1,192.168.122.11,对应k-master210,4h4G
node1,192.168.122.21,对应k-node211,2h4G
node2,192.168.122.22,对应k-node212,2h4G
node3,192.168.122.23,对应node199,2h2G
node4,192.168.122.24,对应node200,4h8G
node5,192.168.122.25,对应node201,4h4G


## 基础服务搭建
### SSL/TLS
SSL/TLS只要是对网络传输的数据进行加密,SSL/TLS首先通过非对称加密的网络通信来协商出一个临时的对称加密密钥(该密钥在两端独立计算出,不在网络中传输),使用对称加密传输网络数据的性能更高.

SSL/TLS加密传输过程:
1. 客户端发起连接请求,客户端发送ClientHello,包括客户端支持的**TLS版本**和一个**客户端随机数**以及客户端支持的**加密套件列表(算法列表)**
2. 服务端收到之后回应一个ServerHello消息,包括:
    - 一个客户端支持的TLS版本
    - 一个加密套件(算法)
    - 一个服务端随机数
    - 服务器证书链
    - 服务器证书和证书链中的所有中间证书
3. 客户端验证服务器证书的有效性: 是否由信任的CA签发,是否在有效期内,证书的域名实发与服务器的域名是否匹配,证书是否已被吊销(通过CRL(证书吊销列表)或OCSP(在线证书状态协议))
4. 客户端生成一个新的随机数(预主密钥),将预主密钥通过服务器公钥加密后传输给服务器,服务器通过私钥揭秘后,双方同时拥有了三个相同的随机数,然后根据确定的算法和这三个随机数生成临时的**会话密钥**
5. 双方交换进行进行验证后开始使用会话密钥加密消息
6. 会话结束后,会话密钥将不再使用,后续的通信需要重新建立新的会话

> 服务器证书中包括: 服务器的域名,服务器的公钥,签发该证书的CA信息,有效期,签发该证书的CA的私钥生成的数字签名

> 客户端在发起ClientHello时可以带上之前的Session ID凭证,如果服务器认可,双方可以直接利用上次握手的参数快速生成新的密钥,这被称为简短握手.

> TLS1.3中,强制使用带有前向安全的算法,客户端不再直接生成与主密钥并通过服务器的公钥发送给服务器(这样一旦服务器私钥泄露,可以直接解密过去所有的握手包),而是通过ECDHE等带有前向安全性的算法,双方各自生成椭圆曲线的公私钥参数互向交换,然后各自独立计算出相同的预主密钥.

客户端验证服务器证书的流程:
1. 客户端通过服务器返回的证书链获取根CA,然后从自己的操作系统或浏览器中查找其内置的根CA列表里中是否包含该根CA
2. 如果找到根CA之后,通过浏览器内置的根CA的公钥向根CA验证第一个中间CA证书上的签名
1. 验证通过之后信任该中间CA并使用该中间CA的公钥验证下一个中间CA的证书签名
1. 直到通过最后一个中间CA验证服务器证书本身的签名


### 自建CA证书
生成私钥:
```
$ sudo mkdir -p /etc/pki/ymyw
$ sudo cd /etc/pki/ymyw
$ sudo openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ca.key
```
创建一个证书签名请求文件(csr):
```
# 创建配置文件
$ sudo vim ca.cnf

[ req ]
default_bits = 2048
prompt = no
distinguished_name = ymyw
[ ymyw ]
C = CN
ST = BJ
L = BJ
O = YMYW
OU = YMYW
CN = ymyw
[ v3_ca ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign

# 根据配置文件和私钥创建证书请求文件
$ sudo openssl req -new -key ca.key -out ca.csr -config ca.cnf 
```

生成CA证书文件:
```
$ sudo openssl x509 -req -days 36500 -in ca.csr -signkey c
a.key -out ca.crt -extfile ca.cnf -extensions v3_ca
```

一共有四个文件:

- ca.cnf: 配置文件,用来生成CSR文件
- ca.key: CA的私钥文件,用于验证下发的证书时解密客户端(用该私钥对应的公钥)加密的证书
- ca.csr: 生成CA证书之前创建的证书签名请求文件,包含了申请者的公钥和身份信息
- ca.crt: CA的公钥证书文件,应该被安装到所有需要验证由该CA签发证书的系统中

> 可以使用`sudo openssl x509 -text -noout -in ca.crt`查看证书的详细内容


下面使用CA证书签发服务器证书:
```
# 生成证书私钥
$ sudo openssl genpkey -algorithm RSA -out server.key
```
创建用于生成CSR的配置文件:
```
$ sudo vim server.cnf
[ req ]
default_bits = 2048
prompt = no
distinguished_name = ymyw
[ ymyw ]
CN = net.ymyw
[ v3_ca ]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature 
extendedKeyUsage = serverAuth, clientAuth, codeSigning
subjectAltName  = @alt_names
[ alt_names ]
IP.1 = 192.168.122.23
DNS.1 = net.ymyw
DNS.1 = *.net.ymyw
```
根据配置文件生成CSR:
```
$ sudo openssl req -new -key server.key -out server.csr -c
onfig server.cnf
```
使用CA签发证书:
```
$ sudo openssl x509 -req -days 36500 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -extfile server.cnf -extensions v3_ca
```
现在同样有四个文件,只需要把crt文件和key文件复制到需要配置证书的nginx上即可.
> 服务器申请证书的流程和CA机构自签名比较类似,主要区别是CA证书中写着`basicConstraints = CA:TRUE`,代表它可以给别人签名.

> 这里是自签名,有些边界比较混乱,实际上服务器在申请CA证书的流程是: 首先生成server.key和server.cnf,然后通过cnf创建csr,将csr提交到CA机构,CA通过某种方式验证你的身份(比如让你在域名下配置一个特定的DNS记录,证明你确实拥有这个域名)验证通过后,CA会使用其根私钥(ca.key)对server.csr进行签名得到server.crt,然后CA机构将server.crt传输给申请者.


### nginx使用证书
把server.crt和server.key放到`/etc/nginx/cert`目录下,然后创建一个配置文件:
```
$ cat /etc/nginx/conf.d/certtest.conf 
server {
        listen 80;
        server_name www.net.ymyw;
        return 301 https://$server_name$request_uri;
}

server {
        listen 443 ssl;
        server_name www.net.ymyw;
        ssl_certificate /etc/nginx/cert/server.crt;
        ssl_certificate_key /etc/nginx/cert/server.key;
        location / {
                root /usr/share/nginx/html;
                index index.html index.htm;
        }
        
}
```

由于是自建CA证书,所以客户端需要手动信任此证书(注意是ca.crt):
```
$ sudo cp ca.crt /usr/local/share/ca-certificates/
$ sudo update-ca-certificates 
```
添加上域名映射(`/etc/hosts`文件)后就可以通过https访问nginx服务了.





