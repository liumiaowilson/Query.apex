/*
 * MIT License
 *
 * Copyright (c) 2018 Click to Cloud Pty Ltd
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
public class Query {

    /* Public members */

    public Query(String objectName) {
        this();

        // Get Schema.SObjectType
        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        this.objectName = objectName;
        this.objectType = globalDescribe.get(objectName);

        if (null == objectType) {
            throw new QueryException('Cannot find corresponding ' +
                    'SObject type from the SObject name' + objectName);
        }

        childRelationships = getChildRelationships();
    }

    /*
     * Specify the selected fields
     * If this function is not called, it would by default select all the fields
     *      with read permission
     */
    public Query selectFields(Set<String> fieldSet) {
        checkFieldLevelSecurity(objectType, fieldSet);
        fields.addAll(fieldSet);
        return this;
    }

    public Query selectFields(List<String> fieldList) {
        return selectFields(new Set<String>(fieldList));
    }

    /*
     * This function allows user provide a single field, or multiple fields
     *      concatenated by ','
     */
    public Query selectFields(String fields) {
        if (fields.contains(',')) {
            // parse the fields separated by ','
            List<String> fieldList = fields.split(', *');
            return selectFields(new Set<String>(fieldList));
        }
        return selectFields(new Set<String>{fields});
    }

    /*
     * Select all user accessible fields
     */
    public Query selectDefaultFields() {
        // Get all the fields
        final Map<String, Schema.SObjectField> fieldMap =
            objectType.getDescribe().fields.getMap();

        // Add the field if it is accessible by the user
        for (String fieldName : fieldMap.keySet()) {
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                fields.add(fieldName);
            }
        }
        return this;
    }

    /*
     * Select all fields from a parent relationship
     * For example, in Contact object, we can call selectParentFields('Account') to select
     *      Account.Name, Account.FirstName, Account.LastName, etc.
     */
    public Query selectParentFields(String parentName) {
        // Get all the fields from the parent object
        final Map<String, Schema.SObjectField> fieldMap =
            getParentObjectType(parentName).getDescribe().fields.getMap();

        if (!parentFields.containsKey(parentName)) {
            parentFields.put(parentName, new Set<String>());
        }
        // Add the field if it is accessible by the user
        for (String fieldName : fieldMap.keySet()) {
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                parentFields.get(parentName).add(fieldName);
            }
        }
        return this;
    }

    /*
     * Select fields from a parent relationship
     * For example,
     *      selectParentFields('Account', new Set<String>{'Name', 'FirstName', 'LastName'})
     *      selects Account.Name, Account.FirstName and Account.LastName.
     */
    public Query selectParentFields(String parentName, Set<String> fields) {
        checkFieldLevelSecurity(getParentObjectType(parentName), fields);

        if (parentFields.containsKey(parentName)) {
            parentFields.get(parentName).addAll(fields);
        } else {
            parentFields.put(parentName, fields);
        }
        return this;
    }

    public Query selectParentFields(String parentName, List<String> fields) {
        return selectParentFields(parentName, new Set<String>(fields));
    }

    /*
     * Select one field or multiple fields concatenated by ',' from a parent relationship
     * Example:
     *      selectParentFields('Account', 'Name, Id')
     *      to select Account.Name and Account.Id
     */
    public Query selectParentFields(String parentName, String fields) {
        if (fields.contains(',')) {
            // parse the fields separated by ','
            List<String> fieldList = fields.split(', *');
            return selectParentFields(parentName, (new Set<String>(fieldList)));
        }
        return selectParentFields(parentName, new List<String>{fields});
    }

    /*
     * Specify the Id of the object
     */
    public Query byIds(Set<Id> idSet) {
        return lookupIds('Id', idSet);
    }

    public Query byIds(List<Id> idList) {
        return byIds(new Set<Id>(idList));
    }

    public Query byIds(Id id) {
        return byIds(new Set<Id>{id});
    }

    /*
     * Specify the Id of a lookup field
     */
    public Query lookupIds(String fieldName, Set<Id> idSet) {
        return addConditionIn(fieldName, idSet);
    }

    public Query lookupIds(String fieldName, List<Id> idList) {
        return lookupIds(fieldName, new Set<Id>(idList));
    }

    public Query lookupIds(String fieldName, Id id) {
        return lookupIds(fieldName, new Set<Id>{id});
    }

    /*
     * Add a condition
     * Example: addConditionEq('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate = :Datetime.now()"
     */
    public Query addConditionEq(String lhs, Object rhs) {
        return addCondition(conditionEq(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionNotEq('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate != :Datetime.now()"
     */
    public Query addConditionNotEq(String lhs, Object rhs) {
        return addCondition(conditionNotEq(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionIn('Name', mySet)
     *          the condition is equivalent to "Name IN :mySet"
     */
    public Query addConditionIn(String lhs, Object rhs) {
        return addCondition(conditionIn(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionNotIn('Name', mySet)
     *          the condition is equivalent to "Name NOT IN :mySet"
     */
    public Query addConditionNotIn(String lhs, Object rhs) {
        return addCondition(conditionNotIn(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionLt('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate < :Datetime.now()"
     */
    public Query addConditionLt(String lhs, Object rhs) {
        return addCondition(conditionLt(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionLe('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate <= :Datetime.now()"
     */
    public Query addConditionLe(String lhs, Object rhs) {
        return addCondition(conditionLe(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionGt('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate < :Datetime.now()"
     */
    public Query addConditionGt(String lhs, Object rhs) {
        return addCondition(conditionGt(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionGe('CreatedDate', Datetime.now())
     *          is equivaGent to "CreatedDate <= :Datetime.now()"
     */
    public Query addConditionGe(String lhs, Object rhs) {
        return addCondition(conditionGe(lhs, rhs));
    }

    /*
     * Add a condition
     * Example: addConditionLike('Name', '%Sam%')
     *          the condition is equivalent to "Name Like :Datetime.now()"
     */
    public Query addConditionLike(String lhs, Object rhs) {
        return addCondition(conditionLike(lhs, rhs));
    }

    /*
     * Add condition with a ConditionType
     */
    public Query addCondition(ConditionType condition) {

        String newConditionString =
            shiftFormatStringIndice(condition.conditionString, conditionArgsIdx);
        saveConditionArg(condition.args);
        return addComplexCondition(newConditionString, condition.args);
    }

    /*
     * Create a condition
     * Example: conditionEq('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate != :Datetime.now()"
     */
    public static ConditionType conditionEq(String lhs, Object rhs) {
        final String formatString = lhs + ' = {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionNotEq('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate != :Datetime.now()"
     */
    public static ConditionType conditionNotEq(String lhs, Object rhs) {
        final String formatString = lhs + ' != {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionIn('Name', mySet)
     *          the condition is equivalent to "Name IN :mySet"
     */
    public static ConditionType conditionIn(String lhs, Object rhs) {
        final String formatString = lhs + ' IN {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionNotIn('Name', mySet)
     *          the condition is equivalent to "Name NOT IN :mySet"
     */
    public static ConditionType conditionNotIn(String lhs, Object rhs) {
        final String formatString = lhs + ' NOT IN {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionLt('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate < :Datetime.now()"
     */
    public static ConditionType conditionLt(String lhs, Object rhs) {
        final String formatString = lhs + ' < {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionLe('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate <= :Datetime.now()"
     */
    public static ConditionType conditionLe(String lhs, Object rhs) {
        final String formatString = lhs + ' <= {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionGt('CreatedDate', Datetime.now())
     *          the condition is equivalent to "CreatedDate < :Datetime.now()"
     */
    public static ConditionType conditionGt(String lhs, Object rhs) {
        final String formatString = lhs + ' > {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionGe('CreatedDate', Datetime.now())
     *          is equivaGent to "CreatedDate <= :Datetime.now()"
     */
    public static ConditionType conditionGe(String lhs, Object rhs) {
        final String formatString = lhs + ' >= {0}';
        return new ConditionType(formatString, rhs);
    }

    /*
     * Create a condition
     * Example: conditionLike('Name', '%Sam%')
     *          the condition is equivalent to "Name Like :Datetime.now()"
     */
    public static ConditionType conditionLike(String lhs, Object rhs) {
        final String formatString = lhs + ' LIKE {0}';
        return new ConditionType(formatString, rhs);
    }

    public static ConditionType doAnd(ConditionType lhs, ConditionType rhs) {
        return lhs.doAnd(rhs);
    }

    public static ConditionType doAnd(ConditionType condition0,
                                      ConditionType condition1,
                                      ConditionType condition2) {
        return doAnd(
                new List<ConditionType>{
                    condition0,
                    condition1,
                    condition2
                }
            );
    }

    public static ConditionType doAnd(ConditionType condition0,
                                      ConditionType condition1,
                                      ConditionType condition2,
                                      ConditionType condition3) {
        return doAnd(
                new List<ConditionType>{
                    condition0,
                    condition1,
                    condition2,
                    condition3
                }
            );
    }

    public static ConditionType doAnd(List<ConditionType> conditions) {
        if (null == conditions || conditions.isEmpty()) {
            return null;
        }

        ConditionType ret = conditions.get(0);

        for (Integer i = 1; i < conditions.size(); i++) {
            ret = ret.doAnd(conditions[i]);
        }

        return ret;
    }

    public static ConditionType doOr(ConditionType lhs, ConditionType rhs) {
        return lhs.doOr(rhs);
    }

    public static ConditionType doOr(ConditionType condition0,
                                     ConditionType condition1,
                                     ConditionType condition2) {
        return doOr(
                new List<ConditionType>{
                    condition0,
                    condition1,
                    condition2
                }
            );
    }

    public static ConditionType doOr(ConditionType condition0,
                                     ConditionType condition1,
                                     ConditionType condition2,
                                     ConditionType condition3) {
        return doOr(
                new List<ConditionType>{
                    condition0,
                    condition1,
                    condition2,
                    condition3
                }
            );
    }


    public static ConditionType doOr(List<ConditionType> conditions) {
        if (null == conditions || conditions.isEmpty()) {
            return null;
        }

        ConditionType ret = conditions.get(0);

        for (Integer i = 1; i < conditions.size(); i++) {
            ret = ret.doOr(conditions[i]);
        }

        return ret;
    }

    /*
     * By default, all the conditions are concatenated by 'AND' keyword
     * Calling switchToDisjunction() will switch the operator to 'OR'
     * Calling switchToConjunction() will switch the operator to 'AND'
     * If anyone wants to use a combination of conjunction and disjunction,
     *      consider using customizeCondition() instead
     */

    /*
     * After calling this function, all conditions will be concatenated by 'AND'
     */
    public Query switchToConjunction() {
        conditionOperator = 'AND';
        return this;
    }

    /*
     * After calling this function, all conditions will be concatenated by 'OR'
     */
    public Query switchToDisjunction() {
        conditionOperator = 'OR';
        return this;
    }

    public Query resetCondition() {
        conditions.clear();
        conditionArgs.clear();

        return this;
    }

    public Query setLimit(Integer n) {
        sizeLimit = n;

        return this;
    }

    public Query orderBy(String fieldName) {
        orderFields.add(fieldName);
        return this;
    }

    public Query orderBy(String fieldName, String orderDirection) {
        // The orderDirection can be only either 'ASC' or 'DESC' ignoring case
        orderFields.add(fieldName);

        if (orderDirection.equalsIgnoreCase('ASC')) {
            ascend();
        } else if (orderDirection.equalsIgnoreCase('DESC')){
            descend();
        }
        return this;
    }

    public Query ascend() {
        ascending = true;
        return this;
    }

    public Query descend() {
        ascending = false;
        return this;
    }

    public Query orderNullsFirst() {
        nullsFirst = true;
        return this;
    }

    public Query orderNullsLast() {
        nullsFirst = false;
        return this;
    }

    public Query addSubquery(String relationshipName) {
        return addChildRelationship(relationshipName);
    }

    public Query addSubquery(String relationshipName,
                                Set<String> fieldSet) {
        addChildRelationship(relationshipName);
        childQuerys.get(relationshipName).selectFields(fields);

        return this;
    }

    public Query addSubquery(String relationshipName,
                                List<String> fieldList) {
        addChildRelationship(relationshipName);
        childQuerys.get(relationshipName).selectFields(fields);

        return this;
    }

    public Query addSubquery(String relationshipName, String fields) {
       addChildRelationship(relationshipName);
        childQuerys.get(relationshipName).selectFields(fields);

        return this;
    }

    public Query addSubquery(Query subquery) {

        return addChildRelationship(subquery);
    }

    public static Query subquery(String relationshipName) {
        Query childQuery = new Query();

        childQuery.objectName = relationshipName;

        return childQuery;
    }

    public Query debug() {
        System.debug(toQueryString());

        for (Integer i = 0; i < conditionArgsIdx; i++) {
            debugDeep(i);
        }
        return this;
    }

    public String toQueryString() {
        return formQueryString();
    }

    public List<SObject> run() {
        String queryString = toQueryString();
        return Database.query(queryString);
    }

    /* Private members */

    private Query() {
        fields = new Set<String>();
        conditions = new List<String>();
        childQuerys = new Map<String, Query>();
        conditionArgs = new List<Object>();
        orderFields = new List<String>();
        parentFields = new Map<String, Set<String>>();
    }

    // State variables
    private Set<String> fields;
    private Map<String, Set<String>> parentFields;

    private List<String> conditions;
    private static final Integer maxArgSize = 20;
    private Integer conditionArgsIdx = 0;
    private List<Object> conditionArgs;
    private Object conditionArgs0;
    private Object conditionArgs1;
    private Object conditionArgs2;
    private Object conditionArgs3;
    private Object conditionArgs4;
    private Object conditionArgs5;
    private Object conditionArgs6;
    private Object conditionArgs7;
    private Object conditionArgs8;
    private Object conditionArgs9;
    private Object conditionArgs10;
    private Object conditionArgs11;
    private Object conditionArgs12;
    private Object conditionArgs13;
    private Object conditionArgs14;
    private Object conditionArgs15;
    private Object conditionArgs16;
    private Object conditionArgs17;
    private Object conditionArgs18;
    private Object conditionArgs19;

    private String conditionOperator = 'AND';
    private Integer sizeLimit = -1;
    private Boolean ascending = true;
    private Boolean nullsFirst = true;
    private List<String> orderFields;
    private Map<String, Query> childQuerys;

    // Object Schema variables 
    private String objectName;
    private Schema.SObjectType objectType;
    private Map<String, Schema.SObjectType> childRelationships;

    private Schema.SObjectType getParentObjectType(String parentName) {
        // translate the reference name
        if (parentName.endsWithIgnoreCase('__r')) {
            parentName = parentName.removeEnd('__r') + '__c';
        } else if (parentName.equalsIgnoreCase('Account') ||
                parentName.equalsIgnoreCase('Owner') ||
                parentName.equalsIgnoreCase('CreatedBy') ||
                parentName.equalsIgnoreCase('LastModifiedBy') ||
                parentName.equalsIgnoreCase('RecordType') ||
                parentName.equalsIgnoreCase('JigsawContact') ||
                parentName.equalsIgnoreCase('MasterRecord') ||
                parentName.equalsIgnoreCase('ReportsTo') ||
                parentName.equalsIgnoreCase('Owner')) {

            parentName = parentName + 'Id';
        }

        parentName = appendNamespace(parentName);

        Schema.SObjectField field = objectType.getDescribe().fields.getMap().get(parentName);

        if (null == field) {
            throw new QueryException('Cannot find field ' + parentName +
                    ' from the object ' + objectName);
        }

        List<Schema.SObjectType> referenceTo =
            field.getDescribe().getReferenceTo();

        if (null == referenceTo || referenceTo.isEmpty()) {
            throw new QueryException('Cannot find parent relationship ' + parentName +
                    ' from the object ' + objectName);
        }

        return referenceTo.get(0);
    }

    private Map<String, Schema.SObjectType> getChildRelationships() {
        Map<String, Schema.SObjectType> childMap =
            new Map<String, Schema.SObjectType>();
        final List<Schema.ChildRelationship> childList =
            objectType.getDescribe().getChildRelationships();

        for (Schema.ChildRelationship child: childList) {
            childMap.put(child.getRelationshipName(), child.getChildSObject());
        }
        return childMap;
    }

    /*
     * Add complex condition with a format string and multiple arguments
     * Example: addComplexCondition('CreatedDate <= {0} AND Name = {1}',
                    new List<Object>{Datetime.now(), 'Sam'})
     */
    @testVisible
    private Query addComplexCondition(String formatString,
                                        List<Object> args) {
        List<String> argStringList = new List<String>();

        conditions.add(String.escapeSingleQuotes(formatString));
        conditionArgs.addAll(args);

        return this;
    }

    /*
     * Save the arg to the member variable
     */
    private void saveConditionArg(List<Object> args) {
        for (Object arg : args) {
            saveConditionArg(conditionArgsIdx, arg);
            conditionArgsIdx++;
        }
    }

    private void saveConditionArg(Integer idx, Object arg) {
        if (idx >= maxArgSize) {
            throw new QueryException('The number of arguments exceeds the limit');
        }

        if (idx == 0) {
            conditionArgs0 = arg;
        } else if (idx == 1) {
            conditionArgs1 = arg;
        } else if (idx == 2) {
            conditionArgs2 = arg;
        } else if (idx == 3) {
            conditionArgs3 = arg;
        } else if (idx == 4) {
            conditionArgs4 = arg;
        } else if (idx == 5) {
            conditionArgs5 = arg;
        } else if (idx == 6) {
            conditionArgs6 = arg;
        } else if (idx == 7) {
            conditionArgs7 = arg;
        } else if (idx == 8) {
            conditionArgs8 = arg;
        } else if (idx == 9) {
            conditionArgs9 = arg;
        } else if (idx == 10) {
            conditionArgs10 = arg;
        } else if (idx == 11) {
            conditionArgs11 = arg;
        } else if (idx == 12) {
            conditionArgs12 = arg;
        } else if (idx == 13) {
            conditionArgs13 = arg;
        } else if (idx == 14) {
            conditionArgs14 = arg;
        } else if (idx == 15) {
            conditionArgs15 = arg;
        } else if (idx == 16) {
            conditionArgs16 = arg;
        } else if (idx == 17) {
            conditionArgs17 = arg;
        } else if (idx == 18) {
            conditionArgs18 = arg;
        } else if (idx == 19) {
            conditionArgs19 = arg;
        }
    }

    private String formQueryString() {
        conditionArgsIdx = 0;

        String query = 'SELECT ';

        query += formFieldString();

        query += ' FROM ' + objectName;

        final String conditionString = formConditionString();

        if (String.isNotBlank(conditionString)) {
            query += ' WHERE ' + conditionString;
        }

        if (!orderFields.isEmpty()) {
            query += ' ORDER BY ' + formOrderByString();
        }

        if (sizeLimit >= 0) {
            query += ' LIMIT ' + sizeLimit;
        }

        return query;
    }

    private String formFieldString() {
        String fieldString = '';

        if (fields.isEmpty()) {
            selectDefaultFields();
        }

        for (String field: fields) {
            fieldString += field + ', ';
        }

        for (String parentRelationship : parentFields.keySet()) {
            for (String field : parentFields.get(parentRelationship)) {
                fieldString += parentRelationship + '.' + field + ', ';
            }
        }

        fieldString += formSubqueryString();

        fieldString = fieldString.removeEnd(', ');

        return fieldString;
    }

    private String formConditionString() {
        String conditionString = '';

        for (String condition : conditions) {
            conditionString += condition;
            // either 'AND' or 'OR'
            conditionString += ' ' + conditionOperator +  ' ';
        }

        // remove either 'AND' or 'OR' in the end
        conditionString = conditionString.removeEnd(' ' + conditionOperator + ' ');

        // shift the arg index
        conditionString = shiftFormatStringIndice(conditionString, conditionArgsIdx);
        saveConditionArg(conditionArgs);

        // format the arguments
        List<String> args = new List<String>();
        for (Integer i = 0; i < conditionArgsIdx; i++) {
            args.add(':conditionArgs' + i);
        }
        conditionString = format(conditionString, args);

        return conditionString;
    }

    private String formSubqueryString() {
        String subqueryString = '';

        for (String key: childQuerys.keySet()) {
            Query childQuery = childQuerys.get(key);

            subqueryString += '(';
            subqueryString += childQuery.toQueryString();
            subqueryString += ')';
            subqueryString += ', ';

            subqueryString = shiftArgStringIndice(subqueryString, conditionArgsIdx);
            saveConditionArg(childQuery.conditionArgs);
        }

        return subqueryString;
    }

    private String formOrderByString() {
        String orderByString = '';
        for (String field : orderFields) {
            orderByString += field + ', ';
        }

        orderByString = orderByString.removeEnd(', ');

        if (ascending) {
            orderByString += ' ASC';
        } else {
            orderByString += ' DESC';
        }

        if (nullsFirst) {
            orderByString += ' NULLS FIRST';
        } else {
            orderByString += ' NULLS LAST';
        }

        return orderByString;
    }

    private Boolean checkFieldLevelSecurity(Schema.SObjectType objType, Set<String> fields) {
        // Get all the fields
        final Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();

        // Check field level security
        for (String field: fields) {
            field = appendNamespace(field);
            if (null == fieldMap.get(field)) {
                throw new QueryException('Cannot find ' + field +
                        ' in object ' + objectName);
            }
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new QueryException('Permission denied: ' +
                        'cannot read ' + field + ' from ' + objectName);
            }
        }

        return true;
    }

    /*
     * Convert a String set to String
     * Sample result format: ('00190000020tGy4AAE', 'a0390000017tZFpAAM')
     */
    private static String convertStringSetToString(Set<Object> items) {
        String result = '(';

        for (Object item : items) {
            result += '\'' + String.escapeSingleQuotes(String.valueOf(item)) + '\', ';
        }
        result = result.removeEnd(', ');
        result += ')';

        return result;
    }

    /*
     * Convert a Value set to String
     * Sample result format: (123.2, 324)
     */
    private static String convertValueSetToString(Set<Object> items) {
        String result = '(';

        for (Object item : items) {
            result += String.valueOf(item) + ', ';
        }
        result = result.removeEnd(', ');
        result += ')';

        return result;
    }

    /*
     * This function shifts the index in the given format string
     * Example:
     *  after passing
     *      'The {0} quick {1} brown {2} fox {3} jumps over the {4} lazy {5} dog',
     *      and shift 2,
     *  The returned string is
     *      'The {2} quick {3} brown {4} fox {5} jumps over the {6} lazy {7} dog'.
     */
    private static String shiftFormatStringIndice(String formatString, Integer shift) {
        for (Integer i = maxArgSize - shift - 1; i >= 0; i--) {
            final String target = '{' + i + '}';
            final String replacement = '{' + (i + shift) + '}';

            formatString = formatString.replace(target, replacement);
        }

        return formatString;
    }

    /*
     * This function shifts the conditionArg index in the given string
     * Example:
     *  after passing
     *      'Name = :conditionArgs0 AND Phone = :conditionArgs1'
     *      and shift 2,
     *  The returned string is
     *      'Name = :conditionArgs2 AND Phone = :conditionArgs3'
     */
    private static String shiftArgStringIndice(String argString, Integer shift) {
        for (Integer i = maxArgSize - shift - 1; i >= 0; i--) {
            final String target = ':conditionArgs' + i;
            final String replacement = ':conditionArgs' + (i + shift);

            argString = argString.replace(target, replacement);
        }

        return argString;
    }

    /*
     * Replacement of String.format
     */
    private static String format(String formatString, List<String> args) {
        for (Integer i = 0; i < args.size(); i++) {
            formatString = formatString.replaceAll('\\{' + i + '\\}', args[i]);
        }
        return formatString;
    }

    private void debugDeep(Integer idx) {
        if (idx == 0) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs0));
        } else if (idx == 1) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs1));
        } else if (idx == 2) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs2));
        } else if (idx == 3) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs3));
        } else if (idx == 4) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs4));
        } else if (idx == 5) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs5));
        } else if (idx == 6) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs6));
        } else if (idx == 7) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs7));
        } else if (idx == 8) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs8));
        } else if (idx == 9) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs9));
        } else if (idx == 10) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs10));
        } else if (idx == 11) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs11));
        } else if (idx == 12) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs12));
        } else if (idx == 13) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs13));
        } else if (idx == 14) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs14));
        } else if (idx == 15) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs15));
        } else if (idx == 16) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs16));
        } else if (idx == 17) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs17));
        } else if (idx == 18) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs18));
        } else if (idx == 19) {
            System.debug('conditionArgs' + idx + ': ' + toString(conditionArgs19));
        }
    }

    /*
     * Convert an argument to a part of a query string
     * If the argument is a list or a set, the string has brackets surrounded
     * Otherwise it returns the string representation of the input
     */
    private static String toString(Object obj) {
        if (obj instanceOf Set<Id>) {
            return toString((Set<Id>)obj);
        } else if (obj instanceOf Set<String>) {
            return toString((Set<String>)obj);
        } else if (obj instanceOf Set<Integer>) {
            return toString((Set<Integer>)obj);
        } else if (obj instanceOf Set<Decimal>) {
            return toString((Set<Decimal>)obj);
        } else if (obj instanceOf List<String> ||
                   obj instanceOf List<Id>) {
            return toString((List<String>)obj);
        } else if (obj instanceOf List<Decimal> ||
                   obj instanceOf List<Integer>) {
            return toString((List<Decimal>)obj);
        } else if (obj instanceOf Id ||
                   obj instanceOf String) {
            return '\'' + String.valueOf(obj) + '\'';
        } else {
            return String.valueOf(obj);
        }
    }

    private static String toString(Set<Id> items) {
        return convertStringSetToString(toObjectSet(items));
    }

    private static String toString(Set<String> items) {
        return convertStringSetToString(toObjectSet(items));
    }

    private static String toString(Set<Integer> items) {
        return convertValueSetToString(toObjectSet(items));
    }

    private static String toString(Set<Decimal> items) {
        return convertValueSetToString(toObjectSet(items));
    }

    private static String toString(List<String> items) {
        return convertStringSetToString(toObjectSet(items));
    }

    private static String toString(List<Decimal> items) {
        return convertValueSetToString(toObjectSet(items));
    }

    /*
     * Convert a collection to Set<Object>
     */
    private static Set<Object> toObjectSet(Set<Id> items) {
        Set<Object> result = new Set<Object>();
        for (Id item: items) {
            result.add(item);
        }
        return result;
    }

    private static Set<Object> toObjectSet(Set<String> items) {
        Set<Object> result = new Set<Object>();
        for (String item: items) {
            result.add(item);
        }
        return result;
    }

    private static Set<Object> toObjectSet(Set<Integer> items) {
        Set<Object> result = new Set<Object>();
        for (Integer item: items) {
            result.add(item);
        }
        return result;
    }

    private static Set<Object> toObjectSet(Set<Decimal> items) {
        Set<Object> result = new Set<Object>();
        for (Decimal item: items) {
            result.add(item);
        }
        return result;
    }

    private static Set<Object> toObjectSet(List<Object> items) {
        Set<Object> result = new Set<Object>();
        for (Object item: items) {
            result.add(item);
        }
        return result;
    }

    private Query addChildRelationship(String relationshipName) {
        if (null == childRelationships.get(relationshipName)) {
            throw new QueryException('Invalid child relationship ' +
                    relationshipName + ' in object ' + objectName);
        }
        Query childQuery = new Query();

        childQuery.objectName = relationshipName;
        childQuery.objectType =
            childRelationships.get(relationshipName);

        childQuerys.put(relationshipName, childQuery);

        return this;
    }

    private Query addChildRelationship(Query childQuery) {
        final String relationshipName = childQuery.objectName;

        if (null == childRelationships.get(relationshipName)) {
            throw new QueryException('Invalid child relationship ' +
                    relationshipName + ' in object ' + objectName);
        }

        childQuery.objectType =
            childRelationships.get(relationshipName);

        childQuerys.put(relationshipName, childQuery);

        return this;
    }

    private static String appendNamespace(String src) {
        if (src.endsWithIgnoreCase('__c')) {
            src = namespace + src;
        }

        return src;
    }

    private static String namespace {
        get {
            if (namespace == null) {
                namespace = getNamespaceFromOrg();
            }
            return namespace;
        }
    }

    private static String getNamespaceFromOrg() {
        List<Organization> orgList =
            [ SELECT namespacePrefix FROM Organization ];

        if (null == orgList || orgList.isEmpty()) {
            return '';
        } else {
            return orgList.get(0).namespacePrefix + '__';
        }
    }

    private class QueryException extends Exception {
    }

    public class ConditionType {
        public ConditionType doAnd(ConditionType other) {
            ConditionType newCondition = this.clone();

            newCondition.conditionString =
                '(' + this.conditionString + ') AND (' +
                shiftFormatStringIndice(other.conditionString, this.args.size()) +
                ')';

            newCondition.args.addAll(other.args);

            return newCondition;
        }

        public ConditionType doOr(ConditionType other) {
            ConditionType newCondition = this.clone();

            newCondition.conditionString =
                '(' + this.conditionString + ') OR (' +
                shiftFormatStringIndice(other.conditionString, this.args.size()) +
                ')';
            newCondition.args.addAll(other.args);

            return newCondition;
        }

        private ConditionType() {
            args = new List<Object>();
        }

        private ConditionType(String formatString, Object arg) {
            this();
            conditionString = formatString;
            args.add(arg);
        }

        private String conditionString;
        private List<Object> args;
    }

}
