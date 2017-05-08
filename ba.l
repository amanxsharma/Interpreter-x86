/* Baby Assembler*/
%{
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_SIZE 65536

long int reg_array[8]; 	/* Array of registers */

int ZERO_IMM = 0;
char* opcode;
char* first_argument;
char* second_argument;
int backpatch[MAX_SIZE];

char* trim(char* yytext);
/***********************Linked List**************************/
struct ln {
   char* key;
   int tag;
   unsigned short value;
   struct ln *next;
};
struct ln *head = NULL;
struct ln *symbol_table = NULL;
int ERROR_FLAG = 0;

void unresolved_label();
void print_ins_mem();
void insert(char* key, int tag, unsigned short value);
void insert_branch(char* key, int tag, unsigned short value);
short occurs(char* key);
unsigned short label_occurs(char* key);
void label_func(char* yytext);
void insert_identifier(char* first_argument,char* second_argument);
long strTOint(char* str);

/**************** Instruction Memory ***********************/
struct instruction{
	unsigned char opcode;
	unsigned char addr_mode:5;
	unsigned char reg_num:3;
    union{
		short imm_val;
		unsigned short address;
		}u;
	};
typedef struct instruction INSTR;
INSTR pc[MAX_SIZE];
unsigned int pc_index=1;
char* OPCODE[19] = {"load","loada","store","move","add","sub","mul","div","mod","cmp","b","blt","ble","bne","beq","bge","bgt","read","write"}; 
char* ADDRESSING_MODE[4] = {"register","direct","indirect","immediate"};
unsigned char addressing_mode_flag = 1; //{register,direct,indirect,immediate}
char* REGISTER[8] = {"r0","r1","r2","r3","r4","r5","r6","r7"};
char* REGISTER_INDIRECT[8] = {"(r0)","(r1)","(r2)","(r3)","(r4)","(r5)","(r6)","(r7)"};
int LAST_COMP=0; //LESS_THAN = -1, EQUAL = 0, GREATER THAN = 1

void execute();
void get_enum_addr(char* second_argument);
void split_alloc(char *yytext);
void split(char *yytext);
void insert_ins_mem(char* opcode,char* first_argument, char* second_argument,int direct_flag);
int get_rx_num(char* argument); 
int get_frx_num(char* argument);//return register num, indirect reg num or immediate value

int islabel(char* argument);

/****************************** Main Memory ******************/

long int free_ptr[MAX_SIZE];
long int free_ptr_index=0;

/******************************Register Array*****************/
struct registers{
    long int PC_reg;
    short int r0,r1,r2,r3,r4,r5,r6,r7;
};
/************************************************************/


%}
	
id				[_A-Za-z][_A-Za-z0-9]*
label			[$]{id}[:]
b_label         [$]{id}
immediate     	[0-9]+
digit           [0-9]
int             {digit}+
rx	        	[rR][0-7]
indirect        "("{rx}")"
ws              [ \t]+
ows             {ws}?


%%
{ows}.alloc{ws}{id}({ows}[,]{ows}{int})?                                               {split_alloc(yytext);} 
{ows}("load"|"loada"|"store"){ws}{rx}[,]{ows}({indirect})                              {split(yytext); 
                                                                                       insert_ins_mem( opcode,first_argument,second_argument,0);}

{ows}("load"|"loada"|"store"){ws}{rx}[,]{ows}({id})                                    {split(yytext); 
                                                                                       insert_ins_mem( opcode,first_argument,second_argument,1);}
{ows}("move"|"add"|"sub"|"mul"|"div"|"mod"|"cmp"){ws}{rx}[,]{ows}({rx}|{immediate})    {split(yytext);
                                                                                        insert_ins_mem( opcode,first_argument,second_argument,0);}
{ows}("b"|"ble"|"blt"|"bne"|"beq"|"bge"|"bgt"){ws}{b_label}                            {split(yytext);
                                                                                        insert_ins_mem( opcode,first_argument,second_argument,0);}
{ows}"read"{ws}{rx}                                                                    {split(yytext);
                                                                                        insert_ins_mem( opcode,first_argument,second_argument,0);}
{ows}"write"{ws}{rx}                                                                   {split(yytext);
                                                                                        insert_ins_mem( opcode,first_argument,second_argument,0);}
{label}                                                                                {yytext[strlen(yytext)-1] = 0; label_func(yytext);}
.|\n   					                                                         	  // { printf("Unrecognized character %s \n",yytext);}

%%

main( int argc, char **argv )
{   

    INSTR pc[MAX_SIZE];
    
    ++argv, --argc;     /* skip over program name */
    if ( argc > 0 ){
        yyin = fopen( argv[0], "r" );
        yyout = fopen( argv[1], "w");
	}
    else{
        yyin = stdin;
        yyout = stderr;
	}
	yylex();

    unresolved_label();
    if(ERROR_FLAG !=1){
    execute(); //ONLY IF NO ERRORS
    return 0;
    }
}
/***********************************************************************************************************************************************/    
void label_func(char* yytext)
{
unsigned short search_node = label_occurs(yytext);
    if(search_node != 0) {
   } else {
      insert(yytext,1,pc_index); //Resolved Label
   }
}
/***********************************************************************************************************************************************/ 
void insert_ins_mem(char* opcode,char* first_argument, char* second_argument,int direct_flag)
{
int i, rx_num;
//Enter Opcode
for(i=0;i<19;i++){
if(strcmp(OPCODE[i],opcode)==0){
    pc[pc_index].opcode=i;
     break;
}
}

if(!*second_argument){ //NO SECOND ARGUMENT
	if(strcmp("write",opcode)==0 || strcmp("read",opcode)==0){ //READ/WRITE..........COMPLETE
		pc[pc_index].addr_mode = '\0';
		pc[pc_index].reg_num = get_frx_num(first_argument); 
        pc[pc_index].u.address = '\0';
		//union will be null;    
	}
	else{ //BRANCHING INS....................COMPLETE...
		pc[pc_index].addr_mode = '\0';
		pc[pc_index].reg_num = '\0';
	    unsigned short search_node = label_occurs(first_argument);
        if(search_node != 0) {
        pc[pc_index].u.address = search_node;
        } 
        else {
        //UNRESOLVED TAG = 2
        pc[pc_index].u.address = 0;
        insert(first_argument,2,pc_index);
        }
	}
}
if(*first_argument && *second_argument && direct_flag==0){ //MOVE AND load with (r0) COMPLETE............
		pc[pc_index].reg_num = get_frx_num(first_argument);
		rx_num = get_rx_num(second_argument);	
		pc[pc_index].u.imm_val = rx_num;
        pc[pc_index].addr_mode = addressing_mode_flag;
	}
	if(direct_flag==1){ // LOAD INSTRUCTIONS with identifier.........Completed
		pc[pc_index].reg_num = get_frx_num(first_argument);
        pc[pc_index].addr_mode = 1; //DIRECT MODE
        short search_node = occurs(second_argument);
        if(search_node >= 0) {
        pc[pc_index].u.address = search_node;
        } 
        else { 
        ERROR_FLAG = 1;
        fprintf(stderr,"ERROR :Identifier not found.\n");        
        }
	}
pc_index++;
}//Enf of function

int get_frx_num(char* argument){
char* temp = (char*) malloc(sizeof(char));
temp = trim(argument);
int i;
char* REGISTER[8] = {"r0","r1","r2","r3","r4","r5","r6","r7"};
//check if matches a register
for(i=0;i<8;i++){
if(strcmp(REGISTER[i],temp)==0){
        break;
}
}
return(i);
}
/*************************************************************************************************************************************************/
void print_ins_mem(){
int h;
for(h=1;h < pc_index;h++){
}
}
/*************************************************************************************************************************************************/

int get_rx_num(char* argument){
char* temp = (char*) malloc(sizeof(char));
temp = trim(argument);
int i,flag=0;
for(i=0;i<8;i++){
if(strcmp(REGISTER[i],temp)==0){
	flag=1; addressing_mode_flag = 0;
        return(i);
}
else if (strcmp(REGISTER_INDIRECT[i],temp)==0){
	flag=1; addressing_mode_flag = 2;
        return(i);
}
}
if(strTOint(temp)!=0){
	flag=1; addressing_mode_flag = 3; //IMMEDIATE
        return(strTOint(temp));
}
else{
	flag=1; addressing_mode_flag = 3; //IMMEDIATE
        ZERO_IMM = 0;
        return(0);
}
}
/*************************************************************************************************************************************************/
void split(char *yytext)
{
char *instruction =   (char*) malloc(sizeof(char));
char *temp =          (char*) malloc(sizeof(char));
first_argument =      (char*) malloc(sizeof(char));
second_argument =     (char*) malloc(sizeof(char));
opcode =              (char*) malloc(sizeof(char));
int i,j;
yytext = trim(yytext); //trim leading spaces, if any
instruction = yytext;
temp = instruction;
for(i=0;temp!='\0'; temp++,i++){
if(isspace((unsigned char) *temp)){
break;
}
}
strncpy(opcode,instruction,i); //instruction only
temp = trim(temp);
char *ins = (char*) malloc(sizeof(char));
ins = temp;
const char *comma = ",";
const char *e; int index;
while(*temp){
    if((strpbrk(temp,comma))!=0){

    e=strchr(temp,',');
    index  = (e-temp);
    
    strncpy(first_argument,ins,index);
    second_argument = trim(strcpy(temp,(strpbrk(temp,comma))+1));
    break;
    }
    else{
    first_argument = temp;
    break;
    }
    temp++;
} //End of while
}
/*************************************************************************************************************************************************/
void split_alloc(char *yytext)
{
char *instruction = (char*) malloc(sizeof(char));
char *temp =        (char*) malloc(sizeof(char));
opcode =            (char*) malloc(sizeof(char));
first_argument =    (char*) malloc(sizeof(char));
second_argument =   (char*) malloc(sizeof(char));
int i,j;
yytext = trim(yytext); //trim leading spaces, if any
strncpy(instruction,yytext+1,strlen(yytext)); //Remove leading .
temp = instruction;
for(i=0;temp!='\0'; temp++,i++){
if(isspace((unsigned char) *temp)){
break;
}
}
strncpy(opcode,instruction,i); //instruction only
temp = trim(temp);
char *ins = (char*) malloc(sizeof(char));
ins = temp;
const char *comma = ",";
const char *e; int index;
while(*temp){
    if((strpbrk(temp,comma))!=0){

    e=strchr(temp,',');
    index  = (e-temp);

    strncpy(first_argument,ins,index);
    second_argument = trim(strcpy(temp,(strpbrk(temp,comma))+1));
    break;
    }
    else{
    first_argument = temp;
    break;
    }
    
    temp++;
} //End of while
insert_identifier(first_argument,second_argument); //for identifier and VAR mode
}//End of function
/*************************************************************************************************************************************************/
long strTOint(char* str){
    int i,base=10;    
    char*end;
    if(strtol(str, &end, base)!=0){
    return(strtol(str, &end, base));}
    else{
    ZERO_IMM = 1;
    return 0;
    }
}
/*************************************************************************************************************************************************/
void insert_identifier(char* first_argument,char* second_argument){
short search_node = occurs(first_argument);
    if(search_node >= 0) {
      //ERROR_FLAG = 1;    
      fprintf(stderr,"ERROR Identifier already allocated memory \n");  
   } else {
      if(strTOint(second_argument) > MAX_SIZE){
      fprintf(stderr,"ERROR: Allocation exceeds MAX allowed limit\n");
      //ERROR_FLAG = 1;
      }
      else{
      insert(first_argument,0,free_ptr_index);   //0 VAR MODE, IDENTIFIER
      free_ptr_index = free_ptr_index + strTOint(second_argument);
      }
   }
}
/*************************************************************************************************************************************************/
char* trim(char* yytext){
while(isspace((unsigned char)*yytext)) yytext++;
return yytext;
}
/*************************************************** void printlist()******************************************************************************/
//display the list
void unresolved_label() {
   struct ln *ptr = head;
	
   //start from the beginning
   while(ptr != NULL) {
      if(ptr->tag == 2){
      fprintf(stderr,"ERROR: Unresolved Label Found\n");
      //ERROR_FLAG=1;
      }
      ptr = ptr->next;
   }
	
}

/********************************************** void insert(char* key, int tag, unsigned short value)***********************************************/
//insert new_node at the first location
void insert(char* key, int tag, unsigned short value) {
   //create a new_node
   struct ln *new_node = (struct ln*) malloc(sizeof(struct ln));
	
   new_node->key = key;
   new_node->tag = tag;
   new_node->value = value;
	
   //point it to old first node
   new_node->next = head;
	
   //point first to new first node
   head = new_node;
}
/************************************************ unsigned short occurs(char* key)**********************************************************************/

//Search node
short occurs(char* key) {
    
   //start from the first link
   struct ln* symbol_table = head;
    
   //if list is empty
   if(head == NULL) {

      return -1;
   }
   //navigate through list

    char *pos = symbol_table->key;
    pos[strcspn(pos, "\n")] = 0;
    symbol_table->key = pos;

   while(strcmp(symbol_table->key,key)!=0) {

      //if it is last node
      if(symbol_table->next == NULL) {
      
         return -1;
      } else {
          
         //go to next link
         symbol_table = symbol_table->next;
      }
   }      

   //if data found, return the symbol_table Link
   
             /*FOR BACKPATCHING*/
          int i=0;
    if(symbol_table->tag==2){
    
        while(backpatch[i]!='\0'){i++;}
        
        backpatch[i] = symbol_table->value;
        symbol_table->value = pc_index;
        backpatch[i+1]='\0';
        printf("Completed\n");
    }
   //if data found, return the symbol_table Link
  
   return symbol_table->value;
}

/**************************************** unsigned short label_occurs(char* key) ***********************************************************************/
   
//Search node
unsigned short label_occurs(char* key) {
    
   //start from the first link
   struct ln* symbol_table = head;
   //if list is empty
   if(head == NULL) {
      return 0;
   }
   //navigate through list

    char *pos = symbol_table->key;
    pos[strcspn(pos, "\n")] = 0;
    symbol_table->key = pos;
   while(strcmp(symbol_table->key,key)!=0) {

      //if it is last node
      if(symbol_table->next == NULL) {
         return 0;
      } else {

         //go to next link
         symbol_table = symbol_table->next;
      }
   }      
   //if data found, return the symbol_table Link
   
   if(symbol_table->tag==1){
    //ERROR_FLAG = 1;
    if(pc[pc_index].opcode == 10 || pc[pc_index].opcode == 11 || pc[pc_index].opcode == 12 || pc[pc_index].opcode == 13 || pc[pc_index].opcode == 14 || pc[pc_index].opcode ==15 || pc[pc_index].opcode ==16){
        }
        else{
        ERROR_FLAG = 1;
        fprintf(stderr,"ERROR: Duplicate occurence of Label %s\n",key);
        }
   }
   
             /*FOR BACKPATCHING*/
          
          if(symbol_table->tag==2){ //UNresolved
          
          
            if(pc[pc_index].opcode == 10 || pc[pc_index].opcode == 11 || pc[pc_index].opcode == 12 || pc[pc_index].opcode == 13 || pc[pc_index].opcode == 14    || pc[pc_index].opcode ==15 || pc[pc_index].opcode ==16){
                
                unsigned short curr_value = symbol_table->value;
                symbol_table->value = pc_index;
                return curr_value;
            }
            else{
                unsigned short f,temp;
                f = symbol_table->value;
                symbol_table->value = pc_index;
                symbol_table->tag = 1;
                while(f != 0){
                     temp = pc[f].u.address;
                     pc[f].u.address = pc_index;
                     f = temp;
                }
            }
          }
return symbol_table->value;         
}
/******************************************************** void execute()********************************************************************************/
void execute(){
int h;
int loop_pc_index = pc_index;
for(h=1;h <= loop_pc_index;h++){
if(pc[h].opcode < 0){
break;
}
switch(pc[h].opcode){
case 18:{ //........................................................WRITE
    printf("%ld\n",reg_array[(pc[h].reg_num)]);
    break;
}
case 17:{
//........................................................READ
    long int read_input;
    scanf("%ld",&read_input);
    reg_array[(pc[h].reg_num)] = read_input;
    break;
}

 //........................................................BRANCHING
case 16:{
    if(LAST_COMP==1){ //........................bgt
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 15:{
    if(LAST_COMP == 1 || LAST_COMP==0){ //...........bge
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 14:{
    if(LAST_COMP==0){ //......................beq
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 13:{
if(LAST_COMP!=0){ //......................bne
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 12:{
if(LAST_COMP==-1 || LAST_COMP==0){ //...........ble
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 11:{
if(LAST_COMP==-1){ //...........................blt
        pc_index = pc[h].u.address;
        h = pc_index-1;
    }
    break;
}
case 10:{ //.................................b
    pc_index = pc[h].u.address;
    h = pc_index-1;
    break;
}
case 9:{ //...............................cmp
    if(pc[h].addr_mode==0){ //Register addr_mode
      if(reg_array[pc[h].reg_num] < reg_array[pc[h].u.imm_val]){
            LAST_COMP = -1;
        }
        if(reg_array[pc[h].reg_num] == reg_array[pc[h].u.imm_val]){
            LAST_COMP = 0;
        }
        if(reg_array[pc[h].reg_num] > reg_array[pc[h].u.imm_val]){
        LAST_COMP = 1;
        }   
    }
    if(pc[h].addr_mode==3){ //Immediate mode
        if(reg_array[pc[h].reg_num] < pc[h].u.imm_val){
            LAST_COMP = -1;
        }
        if(reg_array[pc[h].reg_num] == pc[h].u.imm_val){
            LAST_COMP = 0;
        }
        if(reg_array[pc[h].reg_num] > pc[h].u.imm_val){
            LAST_COMP = 1;
        }
    }
    break;
}
case 8:{ //..................................................mod
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) % (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) % (pc[h].u.imm_val);
    }
    break;
}
case 7:{ //..................................................div
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) / (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) / (pc[h].u.imm_val);
    }
    break;
}
case 6:{ //...................................................mul
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) * (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) * (pc[h].u.imm_val);
    }
    break;
}
case 5:{ //.....................................................sub
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) - (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) - (pc[h].u.imm_val);
    }
    break;
}
case 4:{ //.....................................................add
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) + (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].reg_num]) + (pc[h].u.imm_val);
    }
    break;
}
case 3:{ //......................................................move
    if(pc[h].addr_mode == 0){ //Register addr_mode
    reg_array[pc[h].reg_num] = (reg_array[pc[h].u.imm_val]);
    }
    if(pc[h].addr_mode == 3){ //Immediate addr_mode
    reg_array[pc[h].reg_num] = (pc[h].u.imm_val);
    }
    break;
}
case 2:{ //.......................................................store
    if(pc[h].addr_mode == 1){ //DIRECT addr_mode
    free_ptr_index = pc[h].u.address; //u.address will hold  index of main memory
    free_ptr[free_ptr_index] = reg_array[pc[h].reg_num]; // store register to main memory
    }
    if(pc[h].addr_mode == 2){ //INDIRECT addr_mode
    free_ptr_index = reg_array[pc[h].u.address]; //value in register will be index to Main memory
    free_ptr[free_ptr_index] = reg_array[pc[h].reg_num]; //store register to main memory
    }
    break;
}
case 1:{ //...........................................................loada
    if(pc[h].addr_mode == 1){ //DIRECT addr_mode
    free_ptr_index = pc[h].u.address; //u.address will hold  index/address of main memory
    reg_array[pc[h].reg_num] = free_ptr_index; // Load register with this address
    }
    if(pc[h].addr_mode == 2){ //INDIRECT addr_mode
    free_ptr_index = reg_array[pc[h].u.address]; //value in register will be index to Main memory
    reg_array[pc[h].reg_num] = free_ptr_index; //Load register with this address
    }
    break;
}
case 0:{  //...........................................................load
    if(pc[h].addr_mode == 1){ //DIRECT addr_mode
    free_ptr_index = pc[h].u.address; //u.address will hold  index of main memory
    reg_array[pc[h].reg_num] = free_ptr[free_ptr_index]; // Load register from value in main memory
    }
    if(pc[h].addr_mode == 2){ //INDIRECT addr_mode
    free_ptr_index = reg_array[pc[h].u.address]; //value in register will be index to Main memory
    reg_array[pc[h].reg_num] = free_ptr[free_ptr_index]; //Load register from value in main memory
    }
    break;
}
}
}
}