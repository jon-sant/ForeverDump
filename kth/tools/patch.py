import sys
def sub(path, old, new, count=1):
    raw = open(path, 'rb').read().decode('utf-8')
    crlf = '\r\n' in raw
    s = raw.replace('\r\n', '\n')
    n = s.count(old)
    if n != count:
        sys.exit('PATCH FAIL %s: expected %d got %d for:\n%s' % (path, count, n, old[:200]))
    s = s.replace(old, new)
    if crlf: s = s.replace('\n', '\r\n')
    open(path, 'wb').write(s.encode('utf-8'))
