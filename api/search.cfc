<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna"s
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent output="false" extends="authentication">

	<!--- Create search collection --->
	<cffunction name="search" access="remote" output="false" returntype="struct" returnformat="json">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<cfargument name="secret" required="true" type="string">
		<cfargument name="startrow" required="true" type="numeric">
		<cfargument name="maxrows" required="true" type="numeric">
		<cfargument name="folderid" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">
		<cfargument name="search_upc" required="false" type="string" default="false">
		<!--- <cfset console(arguments)> --->
		<cfset consoleoutput(true, true)>
		<cfset console("#now()# ---------------------- Starting Search")>
		<cfset consoleoutput(false, false)>
		<!--- Check login --->
		<cfset auth(arguments.secret)>
		<!--- Param --->
		<cfset r.success = true>
		<cfset r.error = "">
		<cfset r.results = "">
		<!--- Call internal function --->
		<cfinvoke method="_search" returnvariable="r.results">
			<cfinvokeargument name="collection" value="#arguments.collection#" />
			<cfinvokeargument name="criteria" value="#arguments.criteria#" />
			<cfinvokeargument name="arg_category" value="#arguments.category#" />
			<cfinvokeargument name="startrow" value="#arguments.startrow#" />
			<cfinvokeargument name="maxrows" value="#arguments.maxrows#" />
			<cfinvokeargument name="folderid" value="#arguments.folderid#" />
			<cfinvokeargument name="search_type" value="#arguments.search_type#" />
			<cfinvokeargument name="search_rendition" value="#arguments.search_rendition#" />
			<cfinvokeargument name="search_upc" value="#arguments.search_upc#" />
		</cfinvoke>
		<!--- Return --->
		<cfreturn r />
	</cffunction>




	<!--- PRIVATE --->




	<!--- Internal search --->
	<cffunction name="_search" access="private" output="false" returntype="query">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="arg_category" required="true" type="string">
		<cfargument name="startrow" required="true" type="numeric">
		<cfargument name="maxrows" required="true" type="numeric">
		<cfargument name="folderid" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">
		<cfargument name="search_upc" required="false" type="string" default="false">
		<!--- Param --->
		<cfset var results = querynew("category, categorytree, rank, searchcount")>
		<cfset var folderlist = "" />
		<cfset var _searchcount = 0 />
		<!--- Search --->
		<cftry>
			<!--- Syntax --->
			<cfset var _criteria = _searchSyntax(criteria=arguments.criteria, search_type=arguments.search_type, search_rendition=arguments.search_rendition, host_id=arguments.collection) />
			<!--- if the folderid is not 0 we need to filter by folderid --->
			<cfif arguments.folderid NEQ "0">
				<!--- New list var --->
				<cfset var counter_folderlist = 0>
				<!--- If more than 500 folders do the split, else normal operation --->
				<cfif listlen(arguments.folderid) GTE 500>
					<!--- Create new temp query for lucene results --->
					<cfset var _tmp_results = queryNew("category, categorytree, rank, searchcount")>
					<!--- Create new list --->
					<cfset "variables.folderlist_#counter_folderlist#" = "">
					<!--- Loop over folders --->
					<cfloop list="#arguments.folderid#" index="folderid">
						<!--- If we have more than 200 in the current list create a new list --->
						<cfif listlen(variables["folderlist_" & counter_folderlist], " ") GTE 500>
							<!--- Increase counter --->
							<cfset counter_folderlist++>
							<!--- Create new list with new counter --->
							<cfset "variables.folderlist_#counter_folderlist#" = "">
						</cfif>
						<!--- Append to list --->
						<cfset "variables.folderlist_#counter_folderlist#" = variables["folderlist_" & counter_folderlist] & ' folder:("#folderid#") folder_alias:("#folderid#")'>
					</cfloop>
					<!--- We go the individual folder lists, now loop over it and put together the criteria and search in Lucene --->
					<cfloop from="0" to="#counter_folderlist#" index="n">
						<!--- If the returning _criteria is empty we only tag on the folderlist (with this fix user can search with *) --->
						<cfif _criteria EQ "">
							<cfset "variables.criteria_#n#" = "( " & variables["folderlist_" & n] & " )" />
						<cfelse>
							<cfset "variables.criteria_#n#" = "( #_criteria# ) AND ( " & variables["folderlist_" & n] & " )" />
						</cfif>
						<!--- Call internal function. Search all records --->
						<cfset "variables.results_#n#" = _embeddedSearch(collection=arguments.collection, criteria=variables["criteria_" & n], category=arguments.arg_category, startrow=0, maxrows=0, search_upc=arguments.search_upc)>
						<!--- Set result in variable as QoQ can't handle complex variables --->
						<cfset var _thisqry = variables["results_" & n]>
						<!--- Add up the searchcount --->
						<cftry>
							<cfset var _searchcount = _searchcount + _thisqry.searchcount>
							<cfcatch type="any"></cfcatch>
						</cftry>
						<!--- Add lucene query to tmp results --->
						<cfquery dbtype="query" name="_tmp_results">
						SELECT category, categorytree, rank, searchcount, folder
						FROM _tmp_results
						UNION
						SELECT category, categorytree, rank, searchcount, folder
						FROM _thisqry
						ORDER BY rank
						</cfquery>
					</cfloop>
					<!--- Loop over the _tmp_results and add only the rows we need to the final set --->
					<cfoutput query="_tmp_results" startrow="#arguments.startrow#" maxrows="#arguments.maxrows#">
						<cfset var _q = structnew()>
						<cfset _q.category = category>
						<cfset _q.categorytree = categorytree>
						<cfset _q.rank = rank>
						<cfset _q.searchcount = _searchcount>
						<cfset _q.folder = folder>
						<!--- <cfset _q.full_id = categorytree & '-' & category> --->
						<!--- Add to query --->
						<cfset queryaddrow(query=results, data=_q)>
					</cfoutput>
				<cfelse>
					<!--- Since it could be a list --->
					<cfloop list="#arguments.folderid#" index="i" delimiters=",">
						<cfset var folderlist = folderlist & ' folder:("#i#") folder_alias:("#i#")' />
					</cfloop>
					<!--- If the returning _criteria is empty we only tag on the folderlist (with this fix user can search with *) --->
					<cfif _criteria EQ "">
						<cfset var _criteria = "( #folderlist# )" />
					<cfelse>
						<cfset var _criteria = "( #_criteria# ) AND ( #folderlist# )" />
					</cfif>
					<!--- Call internal function --->
					<cfset var results = _embeddedSearch(collection=arguments.collection, criteria=_criteria, category=arguments.arg_category, startrow=arguments.startrow, maxrows=arguments.maxrows, search_upc=arguments.search_upc)>
					<!--- <cfset consoleoutput(true, true)>
					<cfset console("", results)> --->
				</cfif>
			<cfelse>
				<!--- Call internal function --->
				<cfset var results = _embeddedSearch(collection=arguments.collection, criteria=_criteria, category=arguments.arg_category, startrow=arguments.startrow, maxrows=arguments.maxrows, search_upc=arguments.search_upc)>
				<!--- <cfset consoleoutput(true, true)>
				<cfset console("newsearch results:", results)> --->
			</cfif>
			<cfcatch type="any">
				<cfset consoleoutput(true, true)>
				<cfset console("#now()# ---------------------- START Error on search")>
				<cfset console(cfcatch)>
				<cfset console("#now()# ---------------------- END Error on search")>
				<cfset results = querynew("x")>
				<cfset consoleoutput(false, false)>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn results />
	</cffunction>

	<!--- Function for internal searches coming from above --->
	<cffunction name="_embeddedSearch" access="private" output="false">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<cfargument name="startrow" required="true" type="string">
		<cfargument name="maxrows" required="true" type="string">
		<cfargument name="search_upc" required="false" type="string">
		<cfset consoleoutput(true, true)>
		<!--- Var --->
		<cfset var results = querynew("category, categorytree, rank, searchcount")>
		<!--- <cfset console("ARGUMENTS SEARCH UPC : ", arguments.search_upc)> --->
		<cfset consoleoutput(true, true)>
		<cfset console("#now()# ---------------------- SEARCH STARTING  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")>
		<cfset console("SEARCH WITH: #arguments.criteria#")>
		<!--- FOR UPC --->
		<cfset var _leadingWildcard = arguments.search_upc EQ "true" ? true : false>
		<!--- Search in Lucene --->
		<cfif arguments.maxrows NEQ "0">
			<cfsearch collection="#arguments.collection#" criteria="#arguments.criteria#" name="results" category="#arguments.category#" startrow="#arguments.startrow#" maxrows="#arguments.maxrows#" uniquecolumn="categorytree" allowleadingwildcard="#_leadingWildcard#">
		<cfelse>
			<cfsearch collection="#arguments.collection#" criteria="#arguments.criteria#" name="results" category="#arguments.category#" uniquecolumn="categorytree" allowleadingwildcard="#_leadingWildcard#">
		</cfif>
		<!--- <cfset console(results)> --->
		<!--- Only return the columns we need from Lucene --->
		<cfif results.recordcount NEQ 0>
			<cfquery dbtype="query" name="results">
			SELECT category, categorytree, rank, searchcount, folder, categorytree + '-' + category as full_id
			FROM results
			</cfquery>
		</cfif>
		<!--- <cfset console(results)> --->
		<cfset console("#now()# ---------------------- SEARCH DONE: #results.recordcount# records found  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")>
		<cfset consoleoutput(false, false)>
		<!--- Return --->
		<cfreturn results>
	</cffunction>

	<!--- Internal search --->
	<cffunction name="_searchSyntax" access="private" output="false" returntype="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">
		<cfargument name="host_id" required="true" type="numeric">
		<!---
		 Decode URL encoding that is encoded using the encodeURIComponent javascript method.
		 Preserve the '+' sign during decoding as the URLDecode methode will remove it if present.
		 Do not use escape(deprecated) or encodeURI (doesn't encode '+' sign) methods to encode. Use the encodeURIComponent javascript method only.
		--->
		<!--- Params --->
		<cfset var _del = " OR ">
		<cfset var _space = 0>
		<cfset var _count = 0>
		<cfset var _search_string = "">
		<!--- urlDecode --->
		<cfset var criteria = replace(urlDecode(replace(arguments.criteria,"+","PLUSSIGN","ALL")),"PLUSSIGN","+","ALL")>
		<!--- If criteria is empty or user enters * we search with nothing --->
		<cfif criteria EQ "" OR criteria EQ "*">
			<cfset var criteria = "">
		<!--- FOR DETAIL SEARCH WE LEAVE IT ALONE --->
		<cfelseif arguments.search_type EQ "adv">
			<cfset var criteria = criteria>
		<!--- Put search together. If the criteria contains a ":" then we assume the user wants to search with his own fields --->
		<cfelseif NOT criteria CONTAINS ":" AND NOT criteria EQ "*">
			<!--- Escape search string --->
			<cfset criteria = _escapelucenechars(criteria)>
			<!--- If we find AND in criteria --->
			<cfif find(" AND ", criteria) GT 0>
				<!--- Set var --->
				<cfset var _del = " AND ">
				<!--- Now remove all AND or OR in criteria --->
				<cfset criteria = replace(criteria," AND","","ALL")>
				<cfset criteria = replace(criteria," OR","","ALL")>
			</cfif>
			<!--- Are there more than one word --->
			<cfset var _space = find(" ", criteria)>
			<!--- Get Custom Fields --->
			<cfset var _cf_fields = _getCustomFields(host_id=arguments.host_id)>
			<!--- If there is space we loop over all the words in criteria --->
			<cfif _space > 0>
				<!--- How many items in loop --->
				<cfset _total = ListLen(criteria, " ")>
				<!--- Loop over criteria to put together the search string --->
				<cfloop list="#criteria#" delimiters=" " index="word">
					<cfset var _count = _count + 1>
					<!--- if we reach the total count we null the _del --->
					<cfif _count EQ _total>
						<cfset var _del = "">
					</cfif>
					<!--- Put totgether the custom field --->
					<cfset var _the_custom_field = _createCustomFields(fields=_cf_fields,word=word,criteria=criteria)>
					<!--- Search fields --->
					<cfset var _search_fields = _createSearchFields(criteria=criteria,the_word=word)>
					<!--- For each word create the search string --->
					<cfset var _search_string = _search_string & '( ' & _search_fields &  _the_custom_field & ' )' & _del>
				</cfloop>
			<!--- Just one word in criteria --->
			<cfelse>
				<!--- Put totgether the custom field --->
				<cfset var _the_custom_field = _createCustomFields(fields=_cf_fields,word=criteria,criteria=criteria)>
				<!--- Search fields --->
				<cfset var _search_fields = _createSearchFields(criteria=criteria)>
				<!--- The seach string --->
				<cfset var _search_string = _search_fields & _the_custom_field>
			</cfif>

			<!--- Set criteria --->
			<cfset var criteria = _search_string />
		</cfif>
		<!--- Add rendition search to criteria --->
		<cfif arguments.search_rendition EQ "t">
			<cfif criteria EQ "" OR criteria EQ "*">
				<cfset var criteria = 'file_type:original'>
			<cfelse>
				<cfset var criteria = '( ' & criteria & ' ) AND file_type:original'>
			</cfif>
		<cfelse>
			<cfif criteria EQ "" OR criteria EQ "*">
				<cfset var criteria = 'file_type:original'>
			</cfif>
		</cfif>
		<!--- Return --->
		<cfreturn criteria />
	</cffunction>

	<!--- Escapes lucene special characters in a given string --->
	<cffunction name="_escapelucenechars" returntype="String" access="private" returntype="string">
		<cfargument name="lucenestr" type="String" required="true">
		<!---
		The following lucene special characters will be escaped in searches
		\ ! {} [] - && || ()
		The following lucene special characters  will NOT be escaped as we want to allow users to use these in their search criterion
		+ " ~ * ? : ^
		--->
		<cfset lucenestr = replace(arguments.lucenestr,"\","\\","ALL")>
		<cfset lucenestr = replace(lucenestr,"!","\!","ALL")>
		<cfset lucenestr = replace(lucenestr,"{","\{","ALL")>
		<cfset lucenestr = replace(lucenestr,"}","\}","ALL")>
		<cfset lucenestr = replace(lucenestr,"[","\[","ALL")>
		<cfset lucenestr = replace(lucenestr,"]","\]","ALL")>
		<cfset lucenestr = replace(lucenestr,"-","\-","ALL")>
		<cfset lucenestr = replace(lucenestr,"&&","\&&","ALL")>
		<cfset lucenestr = replace(lucenestr,"||","\||","ALL")>
		<cfset lucenestr = replace(lucenestr,"||","\||","ALL")>
		<cfset lucenestr = replace(lucenestr,"(","\(","ALL")>
		<cfset lucenestr = replace(lucenestr,")","\)","ALL")>
		<cfset lucenestr = replace(lucenestr,'"','','ALL')>
		<!--- Return --->
		<cfreturn lucenestr>
	</cffunction>

	<!--- Get all custom fields --->
	<cffunction name="_getCustomFields" access="private" output="false" returntype="string">
		<cfargument name="host_id" type="numeric" required="true">
		<!--- Get Config --->
		<cfset var config = getConfig()>
		<!--- Loop --->
		<cfloop list="#config.conf_db_prefix#" index="prefix" delimiters=",">
			<!--- Param --->
			<cfset var qry = "">
			<!--- Query --->
			<cfquery name="qry_#prefix#" datasource="#application.razuna.datasource#">
			SELECT DISTINCT cf_id
			FROM #prefix#custom_fields
			WHERE cf_enabled = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.host_id#">
			</cfquery>
		</cfloop>
		<!--- Combine above query if there is raz2_ --->
		<cfquery dbtype="query" name="qry">
		SELECT *
		FROM qry_raz1_
		<cfif listfind(config.conf_db_prefix, "raz2_")>
			UNION
			SELECT *
			FROM qry_raz2_
		</cfif>
		</cfquery>
		<!--- Return --->
		<cfreturn valuelist(qry.cf_id) >
	</cffunction>

	<!--- Put custom fields together --->
	<cffunction name="_createCustomFields" access="private" output="false" returntype="string">
		<cfargument name="fields" type="string" required="true">
		<cfargument name="word" type="string" required="true">
		<cfargument name="criteria" type="string" required="true">
		<!--- Param --->
		<cfset var _field = "">
		<!--- Loop over fields --->
		<cfloop list="#arguments.fields#" delimiters="," index="f">
			<!--- Remove - from id --->
			<cfset var _id = replace(f, "-", "", "ALL")>
			<!--- Each id and word--->
			<cfif NOT arguments.criteria CONTAINS "*">
				<cfset var _field = _field & "customfieldvalue:(""" & _id & arguments.word & """) ">
			<cfelse>
				<cfset var _field = _field & "customfieldvalue:(" & _id & arguments.word & ") ">
			</cfif>
		</cfloop>
		<!--- Return --->
		<cfreturn _field>
	</cffunction>

	<!--- Put search fields together --->
	<cffunction name="_createSearchFields" access="private" output="false" returntype="string">
		<cfargument name="criteria" type="string" required="true">
		<cfargument name="the_word" type="string" required="false" default="#arguments.criteria#">
		<!--- Fields --->
		<cfset var _searchfields = '(#arguments.the_word#) filename:(#arguments.the_word#) keywords:(#arguments.the_word#) description:(#arguments.the_word#) id:(#arguments.the_word#) labels:(#arguments.the_word#) '>
		<!--- If we find a * in criteria then search contains --->
		<cfif NOT arguments.criteria CONTAINS "*">
			<cfset var _searchfields = '("#arguments.the_word#") filename:("#arguments.the_word#") keywords:("#arguments.the_word#") description:("#arguments.the_word#") id:(#arguments.the_word#) labels:("#arguments.the_word#") '>
		</cfif>
		<!--- Return --->
		<cfreturn _searchfields>
	</cffunction>

</cfcomponent>
