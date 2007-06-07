" File:         "MySqlGenQueryMenu.vim" 
" Last Change:  2007/06/01 11:11:46 .
" Author:       Jean-Christophe Clavier <jcclavier at free dot fr>
" Version:      0.1
" License:      GPL
"
" Object : Generates a menu from files containing queries for a MySQL database
"
" Install : simply drop this file in the plugin directory
"           The help file is to be dropped in your doc
"
"           To init the help tags, start Vim and do either
"           :helptags ~/.vim/doc (for unix)
"           or
"           :helptags ~\vimfiles\doc (for MSWindows)
"           to rebuild the tags file. Do ":help add-local-help" for more details.
"
" This script needs python



let s:cpo_save = &cpo
set cpo&vim
if !exists("g:MQGUserCmdFile")
    let g:MQGUserCmdFile=""
endif
if !exists("g:MQGGenCmdFile")
    let g:MQGGenCmdFile=$VIM . "/plugin/MQGQueriesCmdFile.vim"
endif
if !exists("g:MQGGenMenuFile")
    let g:MQGGenMenuFile=$VIM . "/plugin/MQGMenu.vim"
endif
if !exists("g:MQGQueryFilesDir")
    let g:MQGQueryFilesDir=""
endif
if !exists("g:MQGMenuRoot")
    let g:MQGMenuRoot="&Queries"
endif
if !exists("g:MQGCmdLogFile")
    let g:MQGCmdLogFile=""
endif


command! MQGGenMenu python MQGGenMenu()

"--- MOTEUR DE GENERATION DU MENU

python << EOL
import sys, string, vim
def MQGGenMenu(mrFile=vim.eval('g:MQGUserCmdFile'), mrMenuFile=vim.eval('g:MQGGenMenuFile')):

    # We begin the generation with the custom already ready vim command file
    if mrFile != '':
        mrf=open(mrFile,'r')

        mrm=open(mrMenuFile,'w')
        mrm.write('try\n')
        mrm.write('    :unmenu %s\n' % (string.replace(vim.eval("g:MQGMenuRoot"),'&','')))
        mrm.write('catch /.*/\n')
        mrm.write('    let s:bidon = "bidon"\n')
        mrm.write('endtry\n')

        mrm.write(':amenu %s.Menu\ Utils.Load\ Menu\ File<tab> :so %s<CR>\n' % (vim.eval("g:MQGMenuRoot"), mrMenuFile))
        mrm.write(':amenu %s.Menu\ Utils.Gen\ Menu\ File<tab> :MQGGenMenu<CR>\n' % (vim.eval("g:MQGMenuRoot")))
        mrm.write(':amenu %s.Menu\ Utils.Explore\ QFiles\ dir<tab> :Explore %s<CR>\n' % (vim.eval("g:MQGMenuRoot"), vim.eval("g:MQGQueryFilesDir")))
        if vim.eval("g:MQGUserCmdFile") != '':
            mrm.write(':amenu %s.Menu\ Utils.Edit\ User\ cmd\ file<tab> :e %s<CR>\n' % (vim.eval("g:MQGMenuRoot"), vim.eval("g:MQGUserCmdFile")))
        if vim.eval("g:MQGCmdLogFile") != '':
            mrm.write(':amenu %s.Menu\ Utils.Edit\ Log\ file<tab> :e %s<CR>\n' % (vim.eval("g:MQGMenuRoot"), vim.eval("g:MQGCmdLogFile")))
        mrm.write(':amenu %s.-Separator0- :\n' % (vim.eval("g:MQGMenuRoot")))
        menuEntry=''
        menuCmd=''
        for l in mrf:
            if l[0:7]=='" MENU:':
                menuEntry=string.replace(string.split(l[:-1],': ')[1],' ','\\ ')
            elif l[0:8]=='" GROUP:':
                mrGroup=string.replace(string.split(l[:-1],': ')[1],' ','\\ ')
            elif l[0:10]=='" MENUSEP:':
                mrSep=string.split(l[:-1],': ')[1]
                if string.strip(mrGroup)=='':
                    mrm.write(':amenu %s.-%s- :\n' % (vim.eval("g:MQGMenuRoot"), string.split(l[:-1],': ')[1]))
                else:
                    mrm.write(':amenu %s.%s.-%s- :\n' % (vim.eval("g:MQGMenuRoot"), mrGroup, mrSep))
                menuCmd=''
                menuEntry=''
            elif l[0:7]=='command':
                spltCmdLine=string.split(l[:-1])
                for i in range(1, len(spltCmdLine)):
                    if spltCmdLine[i][0]!='-':
                        menuCmd=spltCmdLine[i]
                        break
                if menuCmd != '' and menuEntry != '':
                    if mrGroup=='':
                        mrm.write(':amenu %s.%s<tab> :%s<CR>\n' % (vim.eval("g:MQGMenuRoot"), menuEntry, menuCmd))
                    else:
                        mrm.write(':amenu %s.%s.%s<tab> :%s<CR>\n' % (vim.eval("g:MQGMenuRoot"), mrGroup, menuEntry, menuCmd))
                    menuCmd=''
                    menuEntry=''
        mrf.close()
        mrm.close()

    # Then we generate the command file and the menu from the query files
    MQGGenQueryMenuForVim(mrMenuFile)
EOL

" FONCTIONS UTILISEES POUR LA GENERATION

python << EOL
import sys, string, vim, re, os, os.path
def headerMacroFile():
    h ="let s:cpo_save = &cpo\n"
    h+="set cpo&vim\n"
    return h

def footerMacroFile():
    f ="let &cpo = s:cpo_save\n"
    f+="unlet s:cpo_save\n"
    return f

def funcDef(rq):
    d ="\npython << EOS\n"
    d+="import time, locale, string\n"
    d+='def %s():\n' % (rq['funcname'])
    return d

def cmdDef(rq):
    c='\n"----------------------------------------------------------------------\n'
    if rq['sep'] != r'\t':
        c+='" SEP: %s\n' % (rq['sep'])
    if rq['group'] != '':
        c+='" GROUP: %s\n' % (rq['group'])
    c+='" MENU: %s\n' % (rq['menu'])
    c+='command! %s python %s()\n' % (rq['funcname'], rq['funcname'])
    return c

def menuDef(rq):
    m=''
    if rq['group'] == '':
        if rq['menusep'] != '':
            m+=':amenu %s.-%s- :\n' % (vim.eval("g:MQGMenuRoot"), rq['menusep'])
        m+=':amenu %s.%s<tab> :%s<CR>\n' % (vim.eval("g:MQGMenuRoot"), string.replace(rq['menu'],' ','\\ '), rq['funcname'])
    else:
        if rq['menusep'] != '':
            m+=':amenu %s.%s.-%s- :\n' % (vim.eval("g:MQGMenuRoot"), string.replace(rq['group'],' ','\\ '), rq['menusep'])
        m+=':amenu %s.%s.%s<tab> :%s<CR>\n' % (vim.eval("g:MQGMenuRoot"), string.replace(rq['group'],' ','\\ '), string.replace(rq['menu'],' ','\\ '), rq['funcname'])
    return m

def endMacro():
    e ="EOS\n\n"
    return e

def macro(rq):
    m =cmdDef(rq)
    m+=funcDef(rq)
    indent='    '
    m+=indent + "locale.setlocale(locale.LC_TIME,'')\n"
    for var in rq["vars"]:
        m+=indent + var + ' = vim.eval(\'input("' + var + ' : ")\')\n'
    # We get the type of the query (insert, update, delete, select) to generate the logfile writing
    # if necessary
    rqt=string.split(string.strip(string.join(rq["rqlines"])))[1]
    writeLogFileStmt=''
    if string.lower(rqt) in ["insert", "update", "delete"] and vim.eval("g:MQGCmdLogFile") != "":
        m+=indent + 'LOG_Cmt = vim.eval(\'input("Comment for log : ")\')\n'
        m+=indent + "logfilename='%s'\n" % (string.replace(vim.eval("g:MQGCmdLogFile"),'\\','\\\\'))
        writeLogFileStmt =indent + "lf=open(logfilename,'a')\n"
        writeLogFileStmt+=indent + "lf.write('-- %s\\n' % (time.strftime(\"%c\")))\n"
        writeLogFileStmt+=indent + "lf.write('-- %s\\n' % (LOG_Cmt))\n"
        writeLogFileStmt+=indent + "lf.write(string.strip(Statmt) + '\\n\\n')\n"
        writeLogFileStmt+=indent + "lf.close\n"
    m+=indent + 'Statmt ='
    indent = ''
    for rql in rq["rqlines"]:
        m+=indent + rql
        indent = '    Statmt+='
    indent='    '
    m+=writeLogFileStmt
    m+=indent + 'vim.command("DBExecSQL %s" % (Statmt))\n'
    m+=endMacro()
    return m

def separator(i):
    s=':amenu %s.-Separator%s- :\n'  % (vim.eval("g:MQGMenuRoot"), str(i))
    return s

def unMenu():
    u ='try\n'
    u+='    :unmenu %s\n' % (string.replace(vim.eval("g:MQGMenuRoot"), '&', ''))
    u+='catch /.*/\n'
    u+='    let s:bidon = "bidon"\n'
    u+='endtry\n'
    return u

def footerMenuFile(macroFile):
    f=':so ' + macroFile + '\n'
    return f

def genMacroFile(rqFile, mcFile, mnFile):
    varSeparator=':'
    rePrmSeparator=re.compile('[:,;]')
    rqf=open(rqFile,'r')
    mcf=open(mcFile,'a')
    mnf=open(mnFile,'a')
    rq={'funcname':'','menu':'','menusep':'','group':'','rqlines':[], 'vars':[], 'sep':r'\t'}
    mcf.write(headerMacroFile())
    mnf.write(separator(1))
    # mnf.write(unMenu())
    for l in rqf:
        if l[0:8]=='-- MENU:':
            rq['menu']=string.split(l,': ')[1][:-1]
        elif l[0:11]=='-- MENUSEP:':
            rq['menusep']=string.split(l,': ')[1][:-1]
        elif l[0:7]=='-- SEP:':
            rq['sep']=string.split(l,': ')[1][:-1]
        elif l[0:9]=='-- GROUP:':
            rq['group']=string.split(l,': ')[1][:-1]
        elif l[0:9]=='-- FNAME:':
            rq['funcname']=string.split(l,': ')[1][:-1]
        elif l[0:9]=='-- PARAM:':
            tmp=rePrmSeparator.split(l)[1:]
            for var in tmp:
                rq['vars'].append(string.strip(var))
        elif len(string.strip(l))>0 and l[0:2]!='--':
            spltl=string.split(l,varSeparator)
            if len(spltl)<=2:
                rq['rqlines'].append('" ' + string.replace(string.strip(l[:-1]),'"','\\"') + ' "\n')
            else:
                line='" '
                for i in range(1, len(spltl), 2):
                    if i > 1:
                        line+='"'
                    line+= spltl[i-1] + '" + ' + spltl[i] + ' + '
                    if spltl[i] not in rq['vars']:
                        rq['vars'].append(spltl[i])
                line+='"' + string.replace(string.strip(spltl[-1]),'"','\\"') + '\\n"\n'
                rq['rqlines'].append(line)
            if ';' in l:
                mcf.write(macro(rq))
                mnf.write(menuDef(rq))
                rq['funcname']=''
                rq['menu']=''
                rq['menusep']=''
                rq['rqlines']=[]
                rq['vars']=[]
                rq['sep']=r'\t'
                # group n'est pas réinitialisé pour pouvoir être factorisé
    mcf.write(footerMacroFile())
    mnf.write(footerMenuFile(mcFile))
    rqf.close()
    mcf.close()
    mnf.close()

def MQGGenQueryMenuForVim(mrMenuFile):
    mrMacroFile=vim.eval('g:MQGGenCmdFile')
    mcf=open(mrMacroFile,'w')
    mcf.close()

    mrDir=vim.eval('g:MQGQueryFilesDir')
    if mrDir != '':
        lstFiles=os.listdir(mrDir)
        lstFiles.sort()
        for file in lstFiles:
            mrFile=os.path.join(mrDir, file)
            if os.path.isfile(mrFile):
                genMacroFile(mrFile, mrMacroFile, mrMenuFile)
    else:
        print "g:MQGQueryFilesDir is not defined !"

def oldMacro(rq):
    m =cmdDef(rq)
    m+=funcDef(rq)
    indent='    '
    host=vim.eval('g:MQGMySQLHost')
    user=vim.eval('g:MQGMySQLUser')
    pwd =vim.eval('g:MQGMySQLPwd')
    db  =vim.eval('g:MQGMySQLDb')
    for var in rq["vars"]:
        m+=indent + var + ' = vim.eval(\'input("' + var + ' : ")\')\n'
    m+=indent + 'db=MySQLdb.connect(host="%s", user="%s", passwd="%s", db="%s")\n' %(host, user, pwd, db)
    m+=indent + 'cur=db.cursor()\n'
    m+=indent + 'Statmt ='
    indent = ''
    for rql in rq["rqlines"]:
        m+=indent + rql
        indent = '    Statmt+='
    indent='    '
    m+=indent + 'cur.execute(Statmt)\n'
    m+=indent + 'numrows=int(cur.rowcount)\n'
    #Affichage dans le résultat du titre menu de la requête
    #m+=indent + 'vim.command("let @r=\'' + string.replace(rq["menu"],"'"," ") + '\\n\'")\n'
    m+=indent + 'vim.command("let @r=\'\'")\n'
    m+=indent + 'for i in range(numrows):\n'
    m+=2 * indent + 'row=cur.fetchone()\n'
    m+=2 * indent + 'sep = \'\'\n'
    m+=2 * indent + 'for elt in row:\n'
    m+=3 * indent + 'vim.command("let @R=\'" + sep + string.replace(str(elt),\"\'\", \"\'\'\") + "\'")\n'
    m+=3 * indent + 'sep = \'' + rq["sep"] + '\'\n'
    m+=2 * indent + 'vim.command("let @R=\'\\n\'")\n'

    #m+=indent + 'print vim.eval("@r")\n'
    m+=indent + 'print "Résultat dans le registre r"\n'
    m+=indent + 'if numrows < 50:\n'
    m+=2 * indent + 'vim.command("echo @r")\n'
    m+=endMacro()
    return m

            
EOL

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save


