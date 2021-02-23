# See http://ipython.org/ipython-doc/1/interactive/public_server.html for more information.
# Configuration file for ipython-notebook.
import os

c = get_config()
c.ServerApp.password = ''
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.profile = u'default'
c.IPKernelApp.matplotlib = 'inline'

CORS_ORIGIN = ''
CORS_ORIGIN_HOSTNAME = ''

if os.environ['CORS_ORIGIN'] != 'none':
    CORS_ORIGIN = os.environ.get('CORS_ORIGIN', '')
    CORS_ORIGIN_HOSTNAME = CORS_ORIGIN.split('://')[1]

headers = {
    'X-Frame-Options': 'ALLOWALL',
        'Content-Security-Policy': """
            default-src 'self' %(CORS_ORIGIN)s; 
            img-src 'self' %(CORS_ORIGIN)s;
            connect-src 'self' %(WS_CORS_ORIGIN)s;
            style-src 'unsafe-inline' 'self' %(CORS_ORIGIN)s;
            script-src 'unsafe-inline' 'self' %(CORS_ORIGIN)s;
        """ % {'CORS_ORIGIN': CORS_ORIGIN, 'WS_CORS_ORIGIN': 'ws://%s' % CORS_ORIGIN_HOSTNAME}
}

c.ServerApp.allow_origin = '*'
c.ServerApp.allow_credentials = True

c.ServerApp.base_url = '/ipython'
c.ServerApp.tornado_settings = {
    'static_url_prefix': '/ipython/static/'
}

'''c.ServerApp.base_url = '%s/ipython/' % os.environ.get('PROXY_PREFIX', '')
c.ServerApp.tornado_settings = {
    'static_url_prefix': '%s/ipython/static/' % os.environ.get('PROXY_PREFIX', '')
}'''

if os.environ.get('NOTEBOOK_PASSWORD', 'none') != 'none':
    c.ServerApp.password = os.environ['NOTEBOOK_PASSWORD']
    del os.environ['NOTEBOOK_PASSWORD']

if CORS_ORIGIN:
    c.ServerApp.allow_origin = CORS_ORIGIN

c.ServerApp.tornado_settings['headers'] = headers