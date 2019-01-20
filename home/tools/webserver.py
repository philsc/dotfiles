#!/usr/bin/env python3

# Copyright Jon Berg , turtlemeat.com
# Modified by nikomu @ code.google.com
# Modified by philsc @ philsc.net

import os
import cgi
import re
import sys
import mimetypes
import http.server
import argparse

BASIC_HTML_PAGE = '''\
<html>
<head>
</head>
<body>
%s</body>
</html>
'''

LIST_PAGE = BASIC_HTML_PAGE % '''\
<form method='POST' enctype='multipart/form-data' action='#'>
File to upload: <input type=file name=upfile><br>
<br>
<input type=submit value=Press> to upload the file!
</form>
<div>
%s
</div>
'''

UPLOAD_ERROR = BASIC_HTML_PAGE % '''\
POST ERROR.
<br><br>
%s
<br>
<a href=".">back</a>
'''

UPLOAD_RESPONSE = BASIC_HTML_PAGE % '''\
POST OK.
<br><br>
File uploaded under name: %s
<br>
<a href=".">back</a>
'''


def _make_dir_listing(path):
  link = '<a href="%s">%s</a><br/>'
  inslist = [link % ('..', '..')]
  for entry in sorted(os.listdir(path)):
    if os.path.isdir(os.path.join(path, entry)):
      entry += '/'
    inslist.append(link % (entry, entry))

  return LIST_PAGE % ('\n'.join(inslist))


def _make_path_safe(path):
  return re.sub('^[./]*/', './', path)


class MyHandler(http.server.BaseHTTPRequestHandler):

  def do_GET(self):
    safe_path = _make_path_safe(self.path)

    try:
      if safe_path.endswith('/'):
        self._send_html(_make_dir_listing(safe_path))

      else:
        # Note that if there's a bug in this logic, then this potentially makes
        # every file on your computer readable by the internet.
        with open(os.path.join(os.curdir, safe_path), 'rb') as f:
          mime_type, _ = mimetypes.guess_type(safe_path)
          print('mime_type = ' + mime_type)
          self._send_bytes(mime_type or 'application/octet-stream', f.read())

    except IOError as e:
      print(e)
      self.send_error(404, 'File Not Found: %s' % self.path)

  def do_POST(self):
    try:
      ctype, pdict = cgi.parse_header(self.headers.get('content-type'))

      if ctype == 'multipart/form-data':
        fs = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={
                              'REQUEST_METHOD': 'POST'})
      else:
        raise Exception("Unexpected POST request")

      fs_up = fs['upfile']
      path = _make_path_safe(self.path)
      filename = os.path.split(fs_up.filename)[1]
      basename = os.path.join(path, filename)
      newname = basename

      if not filename:
        self._send_html(UPLOAD_ERROR % ("Empty filename specified."))
        return

      # If a file under that name already exists, save it to <name>.copy(X)
      i = 1
      while os.path.exists(newname):
        newname = basename + '.copy(%d)' % i
        i += 1

      with open(newname, 'wb') as f:
        f.write(fs_up.file.read())

      reported_filename = os.path.split(newname)[1]
      print("Received file: %s" % reported_filename)
      self._send_html(UPLOAD_RESPONSE % reported_filename)

    except Exception as e:
      print(e)
      self.send_error(404, 'POST to "%s" failed: %s' % (self.path, str(e)))

  def _send_html(self, html):
    self._send_bytes('text/html', bytes(html, 'UTF-8'))

  def _send_bytes(self, mime_type, data):
    self.send_response(200)
    self.send_header('Content-type', 'text/html')
    self.end_headers()
    self.wfile.write(data)


def main(argv):
  try:
    mimetypes.init()

    parser = argparse.ArgumentParser(
        description='Simple upload/download server')
    parser.add_argument('--port', '-p', type=int, default=8080, action='store',
        help='Port for the server to listen on.')

    args = parser.parse_args(argv[1:])

    server = http.server.HTTPServer(('0.0.0.0', args.port), MyHandler)
    print('started server: http://localhost:%d/' % args.port)
    server.serve_forever()
  except KeyboardInterrupt:
    print('^C received, shutting down server')
    server.socket.close()

if __name__ == '__main__':
  main(sys.argv)
