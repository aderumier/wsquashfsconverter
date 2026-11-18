// virtual xbox360 pad; reads commands on stdin: "btn <name> <0|1>", "axis <name> <value>", "tap <name> <ms>", "sleep <ms>"
#include <linux/uinput.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
static int fd;
static void emit(int t,int c,int v){struct input_event e={0};e.type=t;e.code=c;e.value=v;write(fd,&e,sizeof e);}
static void syn(void){emit(EV_SYN,SYN_REPORT,0);}
struct m{const char*n;int c;} btns[]={{"a",BTN_SOUTH},{"b",BTN_EAST},{"x",BTN_NORTH},{"y",BTN_WEST},{"lb",BTN_TL},{"rb",BTN_TR},{"back",BTN_SELECT},{"start",BTN_START},{"guide",BTN_MODE},{"ls",BTN_THUMBL},{"rs",BTN_THUMBR},{0,0}};
struct m axes[]={{"lx",ABS_X},{"ly",ABS_Y},{"rx",ABS_RX},{"ry",ABS_RY},{"lt",ABS_Z},{"rt",ABS_RZ},{"hx",ABS_HAT0X},{"hy",ABS_HAT0Y},{0,0}};
static int find(struct m*t,const char*n){for(;t->n;t++)if(!strcmp(t->n,n))return t->c;return -1;}
static void absset(int c,int mn,int mx){struct uinput_abs_setup a={0};a.code=c;a.absinfo.minimum=mn;a.absinfo.maximum=mx;if(c<ABS_HAT0X&&c!=ABS_Z&&c!=ABS_RZ){a.absinfo.fuzz=16;a.absinfo.flat=128;}ioctl(fd,UI_ABS_SETUP,&a);}
int main(void){
 fd=open("/dev/uinput",O_WRONLY|O_NONBLOCK); if(fd<0){perror("uinput");return 1;}
 ioctl(fd,UI_SET_EVBIT,EV_KEY);ioctl(fd,UI_SET_EVBIT,EV_ABS);
 for(struct m*b=btns;b->n;b++)ioctl(fd,UI_SET_KEYBIT,b->c);
 for(struct m*a=axes;a->n;a++)ioctl(fd,UI_SET_ABSBIT,a->c);
 absset(ABS_X,-32768,32767);absset(ABS_Y,-32768,32767);absset(ABS_RX,-32768,32767);absset(ABS_RY,-32768,32767);
 absset(ABS_Z,0,255);absset(ABS_RZ,0,255);absset(ABS_HAT0X,-1,1);absset(ABS_HAT0Y,-1,1);
 struct uinput_setup u={0};u.id.bustype=BUS_USB;u.id.vendor=0x045e;u.id.product=0x028e;u.id.version=0x110;strcpy(u.name,"Microsoft X-Box 360 pad");
 ioctl(fd,UI_DEV_SETUP,&u);ioctl(fd,UI_DEV_CREATE);
 setvbuf(stdout,0,_IONBF,0);
 char sn[64]={0},path[160],ev[32]="?";ioctl(fd,UI_GET_SYSNAME(sizeof sn),sn);
 snprintf(path,sizeof path,"/sys/devices/virtual/input/%s",sn);
 for(int i=0;i<50&&ev[0]=='?';i++){DIR*d=opendir(path);struct dirent*e;while(d&&(e=readdir(d)))if(!strncmp(e->d_name,"event",5))snprintf(ev,sizeof ev,"%s",e->d_name);if(d)closedir(d);if(ev[0]=='?')usleep(20000);}
 printf("ready /dev/input/%s\n",ev);
 char l[256],a[64],b[64];int v;
 while(fgets(l,sizeof l,stdin)){
  a[0]=b[0]=0;v=0; int n=sscanf(l,"%63s %63s %d",a,b,&v);
  if(n<1)continue;
  if(!strcmp(a,"sleep")){usleep(atoi(b)*1000);continue;}
  if(!strcmp(a,"quit"))break;
  int c;
  {const char*dn[]={"up","down","left","right"};int dc[]={ABS_HAT0Y,ABS_HAT0Y,ABS_HAT0X,ABS_HAT0X},dv[]={-1,1,-1,1};int k;for(k=0;k<4;k++)if(!strcmp(b,dn[k]))break;
   if(!strcmp(a,"tap")&&k<4){emit(EV_ABS,dc[k],dv[k]);syn();usleep((v?v:150)*1000);emit(EV_ABS,dc[k],0);syn();continue;}}
  if(!strcmp(a,"tap")&&(c=find(btns,b))>=0){emit(EV_KEY,c,1);syn();usleep((v?v:150)*1000);emit(EV_KEY,c,0);syn();continue;}
  if(!strcmp(a,"tap")&&(c=find(axes,b))>=0){int hat=c>=ABS_HAT0X; int val=hat?1:32767; if(b[0]=='h'&&v<0){val=-1;v=-v;} emit(EV_ABS,c,val);syn();usleep((v?v:150)*1000);emit(EV_ABS,c,0);syn();continue;}
  if(!strcmp(a,"btn")&&(c=find(btns,b))>=0){emit(EV_KEY,c,v);syn();continue;}
  if(!strcmp(a,"axis")&&(c=find(axes,b))>=0){emit(EV_ABS,c,v);syn();continue;}
  fprintf(stderr,"bad: %s",l);
 }
 ioctl(fd,UI_DEV_DESTROY);return 0;}
