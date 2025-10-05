function [enuminfo] = daecenums()
    
persistent enums
if isempty(enums)
    enums.version = '0.4.0';
    enums.frequency_t=struct('freq_none',0,'freq_unit',11,'freq_daily',12,'freq_bdaily',13,'freq_weekly',16,'freq_weekly_sun0',16,'freq_weekly_mon',17,'freq_weekly_tue',18,'freq_weekly_wed',19,'freq_weekly_thu',20,'freq_weekly_fri',21,'freq_weekly_sat',22,'freq_weekly_sun7',23,'freq_weekly_sun',23,'freq_monthly',32,'freq_quarterly',64,'freq_quarterly_jan',65,'freq_quarterly_feb',66,'freq_quarterly_mar',67,'freq_quarterly_apr',65,'freq_quarterly_may',66,'freq_quarterly_jun',67,'freq_quarterly_jul',65,'freq_quarterly_aug',66,'freq_quarterly_sep',67,'freq_quarterly_oct',65,'freq_quarterly_nov',66,'freq_quarterly_dec',67,'freq_halfyearly',128,'freq_halfyearly_jan',129,'freq_halfyearly_feb',130,'freq_halfyearly_mar',131,'freq_halfyearly_apr',132,'freq_halfyearly_may',133,'freq_halfyearly_jun',134,'freq_halfyearly_jul',129,'freq_halfyearly_aug',130,'freq_halfyearly_sep',131,'freq_halfyearly_oct',132,'freq_halfyearly_nov',133,'freq_halfyearly_dec',134,'freq_yearly',256,'freq_yearly_jan',257,'freq_yearly_feb',258,'freq_yearly_mar',259,'freq_yearly_apr',260,'freq_yearly_may',261,'freq_yearly_jun',262,'freq_yearly_jul',263,'freq_yearly_aug',264,'freq_yearly_sep',265,'freq_yearly_oct',266,'freq_yearly_nov',267,'freq_yearly_dec',268);
    enums.axis_type_t=struct('axis_plain',0,'axis_range',1,'axis_names',2);
    enums.type_t=struct('type_none',0,'type_integer',1,'type_signed',1,'type_unsigned',2,'type_date',3,'type_float',4,'type_complex',5,'type_string',6,'type_other_scalar',7,'type_vector',10,'type_range',11,'type_tseries',12,'type_other_1d',13,'type_matrix',20,'type_mvtseries',21,'type_other_2d',22,'type_tensor',30,'type_ndtseries',31,'type_other_nd',32,'type_any',-1);
    enums.class_t=struct('class_catalog',0,'class_scalar',1,'class_vector',2,'class_tseries',2,'class_matrix',3,'class_mvtseries',3,'class_tensor',4,'class_ndtseries',4,'class_any',-1);
    enums.status_t=struct('DE_SUCCESS',0,'DE_ERR_ALLOC',-1000,'DE_BAD_AXIS_TYPE',-999,'DE_BAD_NUM_AXES',-998,'DE_BAD_CLASS',-997,'DE_BAD_TYPE',-996,'DE_BAD_ELTYPE',-995,'DE_BAD_ELTYPE_NONE',-994,'DE_BAD_ELTYPE_DATE',-993,'DE_BAD_NAME',-992,'DE_BAD_FREQ',-991,'DE_SHORT_BUF',-990,'DE_OBJ_DNE',-989,'DE_AXIS_DNE',-988,'DE_ARG',-987,'DE_NO_OBJ',-986,'DE_EXISTS',-985,'DE_BAD_OBJ',-984,'DE_NULL',-983,'DE_DEL_ROOT',-982,'DE_MIS_ATTR',-981,'DE_INEXACT',-980,'DE_RANGE',-979,'DE_INTERNAL',-978);
    enums.type_t_by_matlab_class=struct('int32',1,'int64',1,'logical',2,'uint32',2,'uint64',2,'datetime',3,'DEDate',3,'double',4,'char',6,'string',6);
end

enuminfo = enums;

end

