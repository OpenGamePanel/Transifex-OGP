#!/usr/bin/python
# Not actually sure if this works 100% yet, but another reason why it's in source control
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
import SocketServer
import base64
import hmac
import hashlib
import json
import urlparse
import sys
import subprocess

class S(BaseHTTPRequestHandler):
    def _set_headers(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()

    def do_GET(self):
        self._set_headers()
        self.wfile.write("<html><body><h1>Nothing to see here, no health pack!</h1></body></html>")

    def do_HEAD(self):
        self._set_headers()
        
    def do_POST(self):
        self._set_headers()
        try:
                hashVerification = str(self.headers['X-TX-Signature'])
                print "Hash header received from transifex is %s." %hashVerification
                
                content = str(self.rfile.read(int(self.headers['Content-Length'])))
                print "POSTed data content is %s." %content
                
                contentType = str(self.headers['Content-Type'])
                print "Content type is %s." %contentType
                if contentType == "multipart/form-data" or contentType == "application/x-www-form-urlencoded":
                        post_data = urlparse.parse_qs(content)
                        for key, value in post_data.iteritems():
                                print "%s=%s" % (key, value)
                        print "Value of param1 is %s" %post_data['param1'][0]
                elif contentType == "application/json":
                        dataObj = json.loads(content)
                        data = str(dataObj)
                        print "Raw json data is %s." %data
                        h=hmac.new(key='{YOUR_TRANSIFEX_SECRET_KEY_HERE}', msg=data, digestmod=hashlib.sha1)
                        h.hexdigest()
                        hashedData=base64.b64encode(h.digest())
                        if hashVerification == hashedData:
                                print("Received valid transifex message!")							
                                self.wfile.write("<html><body><h1>Message Received. Thanks!</h1></body></html>")
                                command = 'nohup /bin/bash /home/own3mall/transifex/ogp_transifex.sh > /home/own3mall/transifex/logFile 2>&1 &'
                                output,error  = subprocess.Popen(
                                         command, universal_newlines=True, shell=True,
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
                        else:
                                print("Hash %s didn't match %s." % (hashedData, hashVerification))				                                    
                                self.wfile.write("<html><body><h1>Invalid request received.  </h1></body></html>")
                else:
                        self.wfile.write("<html><body><h1>Invalid request received.</h1></body></html>")
        except:
			    self.wfile.write("<html><body><h1>Invalid request received.</h1></body></html>")
        
        
def run(server_class=HTTPServer, handler_class=S, port={PORT_HERE}):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print 'Starting httpd...'
    sys.stderr = open('/home/own3mall/scripts/transifex_logfile_error.txt', 'w', 0)
    sys.stdout = open('/home/own3mall/scripts/transifex_logfile_stdout.txt', 'w', 0)
    sys.stdout.flush()
    httpd.serve_forever()

if __name__ == "__main__":
    from sys import argv

    if len(argv) == 2:
        run(port=int(argv[1]))
    else:
        run()
