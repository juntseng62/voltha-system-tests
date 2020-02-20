# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# onos common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Resource          ./flows.robot

*** Keywords ***
Validate OLT Device in ONOS
    #    FIXME use volt-olts to check that the OLT is ONOS
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serial
        ${matched}=    Set Variable If    '${sn}' == '${serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${serial_number} found
    [Return]    ${of_id}

Get ONU Port in ONOS
    [Arguments]    ${onu_serial_number}    ${olt_of_id}
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    1
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${onu_serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${onu_serial_number} found
    [Return]    ${onu_port}

Get NNI Port in ONOS
    [Arguments]    ${olt_of_id}
    [Documentation]    Retrieves NNI port for the OLT in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${nni_port}=    Get From Dictionary    ${value}    port
        ${nniPortName}=    Catenate    SEPARATOR=    nni-    ${nni_port}
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${nniPortName}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for NNI found for ${olt_of_id}
    [Return]    ${nni_port}

Get FabricSwitch in ONOS
    [Documentation]    Returns of_id of the Fabric Switch in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${type}=    Get From Dictionary    ${value}    type
        ${matched}=    Set Variable If    '${type}' == "SWITCH"    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No fabric switch found
    [Return]    ${of_id}

Verify Subscriber Access Flows Added for ONU
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${c_tag}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:0 |
    ...     grep VLAN_ID:${c_tag} | grep transition=TABLE:1
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_0_cmd}
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_ID:0 | grep OUTPUT:${onu_port}
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_1_cmd}
    Should Not Be Empty    ${downstream_flow_1_added}
    # Verify ipv4 dhcp upstream flow
    ${upstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:68 | grep UDP_DST:67 | grep VLAN_VID:${c_tag} |
    ...     grep OUTPUT:CONTROLLER
    ${upstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_ipv4_cmd}
    Should Not Be Empty    ${upstream_flow_ipv4_added}
    # Verify ipv4 dhcp downstream flow
    # Note: This flow will be one per nni per olt
    ${downstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:67 | grep UDP_DST:68 | grep OUTPUT:CONTROLLER
    ${downstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_ipv4_cmd}
    Should Not Be Empty    ${downstream_flow_ipv4_added}

Verify Subscriber Access Flows Added for ONU DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any | grep transition=TABLE:1
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:Any | grep OUTPUT:${onu_port}
    Should Not Be Empty    ${downstream_flow_1_added}

Verify Subscriber Access Flows Added Count DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of subscriber access flows added for all onus
    ${access_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId | grep -v ETH_TYPE:lldp | wc -l
    Should Be Equal As Integers    ${access_flows_added}    ${expected_flows}

Verify Device Flows Removed
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies all flows are removed from the device
    ${device_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ${olt_of_id} | grep -v deviceId | wc -l
    Should Be Equal As Integers    ${device_flows}    0

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify No Pending Flows For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that there are no flows "PENDING" state for the ONU in ONOS
    ${pending_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s | grep IN_PORT:${onu_port} | grep PENDING
    Should Be Empty    ${pending_flows}

Verify Eapol Flows Added For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the Eapol Flows are added in ONOS for the ONU
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT:${onu_port}
    Should Not Be Empty    ${eapol_flows_added}

Verify ONU Port Is Enabled
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the ONU port is enabled in ONOS
    ${onu_port_enabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep port=${onu_port}
    Log    ${onu_port_enabled}
    Should Not Be Empty    ${onu_port_enabled}

Verify ONU Port Is Disabled
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the ONU port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep port=${onu_port}
    Log    ${onu_port_disabled}
    Should Be Empty    ${onu_port_disabled}

Verify ONU in AAA-Users
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified onu_port exists in aaa-users output
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | grep ${onu_port}
    Should Not Be Empty    ${aaa_users}    ONU port ${onu_port} not found in aaa-users

Assert Number of AAA-Users
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | wc -l
    Should Be Equal As Integers    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}    dhcpl2relay-allocations | grep DHCPACK | wc -l
    Should Be Equal As Integers    ${allocations}    ${expected_onus}

Validate Subscriber DHCP Allocation
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified subscriber is found in DHCP allocations
    ##TODO: Enhance the keyword to include DHCP allocated address is not 0.0.0.0
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    dhcpl2relay-allocations | grep DHCPACK | grep ${onu_port}
    Should Not Be Empty    ${allocations}    ONU port ${onu_port} not found in dhcpl2relay-allocations

Device Is Available In ONOS
    [Arguments]    ${url}    ${dpid}
    [Documentation]    Validates the device exists and it available in ONOS
    ${rc}    ${json}    Run And Return Rc And Output    curl --fail -sSL ${url}/onos/v1/devices/${dpid}
    Should Be Equal As Integers    0    ${rc}
    ${rc}    ${value}    Run And Return Rc And Output    echo '${json}' | jq -r .available
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal    'true'    '${value}'

Remove All Devices From ONOS
    [Arguments]    ${url}
    [Documentation]    Executes the device-remove command on each device in ONOS
    ${rc}    ${output}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/devices | jq -r '.devices[].id'
    Should Be Equal As Integers    ${rc}    0
    @{dpids}    Split String    ${output}
    ${count}=    Get length    ${dpids}
    FOR    ${dpid}    IN    @{dpids}
        ${rc}=    Run Keyword If    '${dpid}' != ''
        ...    Run And Return Rc    curl -XDELETE --fail -sSL ${url}/onos/v1/devices/${dpid}
        Run Keyword If    '${dpid}' != ''
        ...    Should Be Equal As Integers    ${rc}    0
    END

Assert Ports in ONOS
    [Arguments]    ${ip}    ${port}     ${count}     ${filter}
    [Documentation]    Check that a certain number of ports are enabled in ONOS
    ${ports}=    Execute ONOS CLI Command    ${ip}    ${port}
        ...    ports -e | grep ${filter} | wc -l
    Should Be Equal As Integers    ${ports}    ${count}

Wait for Ports in ONOS
    [Arguments]    ${ip}    ${port}     ${count}     ${filter}
    [Documentation]    Waits untill a certain number of ports are enabled in ONOS
    Wait Until Keyword Succeeds     10m     5s      Assert Ports in ONOS   ${ip}    ${port}     ${count}     ${filter}

Wait for AAA Authentication
    [Arguments]    ${ip}    ${port}     ${count}
    [Documentation]    Waits untill a certain number of subscribers are authenticated in ONOS
    Wait Until Keyword Succeeds     10m     5s      Assert Number of AAA-Users      ${ip}    ${port}     ${count}

Wait for DHCP Ack
    [Arguments]    ${ip}    ${port}     ${count}
    [Documentation]    Waits untill a certain number of subscribers have received a DHCP_ACK
    Wait Until Keyword Succeeds     10m     5s      Validate DHCP Allocations      ${ip}    ${port}     ${count}

Provision subscriber
    [Documentation]  Calls volt-add-subscriber-access in ONOS
    [Arguments]    ${onos_ip}    ${onos_port}   ${of_id}    ${onu_port}
    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
            ...    volt-add-subscriber-access ${of_id} ${onu_port}

List Enabled UNI Ports
    [Documentation]  List all the UNI Ports, the only way we have is to filter out the one called NNI
    ...     Creates a list of dictionaries
    [Arguments]     ${onos_ip}    ${onos_port}   ${of_id}
    [Return]  [{'port': '16', 'of_id': 'of:00000a0a0a0a0a00'}, {'port': '32', 'of_id': 'of:00000a0a0a0a0a00'}]
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command    ${onos_ip}    ${onos_port}
    ...    ports -e ${of_id} | grep -v SWITCH | grep -v nni
    @{unis}=    Split To Lines    ${out}
    FOR    ${uni}    IN    @{unis}
        ${matches} =    Get Regexp Matches    ${uni}  .*port=([0-9]+),.*  1
        &{portDict}    Create Dictionary    of_id=${of_id}    port=${matches[0]}
        Append To List  ${result}    ${portDict}
    END
    Log     ${result}
    Return From Keyword     ${result}

Provision all subscribers on device
    [Documentation]  Calls volt-add-subscriber-access in ONOS for all the enabled UNI ports on a partivular device
    [Arguments]     ${onos_ip}    ${onos_port}   ${of_id}
    ${unis}=    List Enabled UNI Ports  ${onos_ip}  ${onos_port}   ${of_id}
    FOR     ${uni}  IN      @{unis}
        Provision subscriber   ${onos_ip}  ${onos_port}   ${uni['of_id']}   ${uni['port']}
    END

List OLTs
    [Documentation]  Returns a list of OLTs known to ONOS
    [Arguments]  ${onos_ip}    ${onos_port}
    [Return]  ['of:00000a0a0a0a0a00', 'of:00000a0a0a0a0a01']
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command    ${onos_ip}    ${onos_port}
    ...     volt-olts
    @{olts}=    Split To Lines    ${out}
    FOR    ${olt}    IN    @{olts}
        Log     ${olt}
        ${matches} =    Get Regexp Matches    ${olt}  ^OLT (.+)$  1
        # there may be some logs mixed with the output so only append if we have a match
        ${matches_length}=      Get Length  ${matches}
        Run Keyword If  ${matches_length}==1
        ...     Append To List  ${result}    ${matches[0]}
    END
    Return From Keyword     ${result}

Count ADDED flows
    [Documentation]  Count the flows in ADDED state in ONOS
    [Arguments]  ${onos_ip}     ${onos_port}    ${targetFlows}
    ${flows}=    Execute ONOS CLI Command    ${onos_ip}    ${onos_port}
    ...     flows -s | grep ADDED | wc -l
    Should Be Equal As Integers    ${targetFlows}    ${flows}

Wait for all flows to in ADDED state
    [Documentation]  Waits until the flows have been provisioned
    [Arguments]  ${onos_ip}    ${onos_port}     ${workflow}    ${uni_count}    ${olt_count}    ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}
    ${targetFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}
    Wait Until Keyword Succeeds     10m     5s      Count ADDED flows
    ...     ${onos_ip}    ${onos_port}  ${targetFlows}

Get Bandwidth Details
    [Arguments]    ${bandwidth_profile_name}
    [Documentation]    Collects the bandwidth profile details for the given bandwidth profile and
    ...    returns the limiting bandwidth
    ${bandwidth_profile_values}=    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    bandwidthprofile ${bandwidth_profile_name}
    @{bandwidth_profile_array}=    Split String    ${bandwidth_profile_values}    ,
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[1]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${cir_value}    Run Keyword If    '${bandwidthparameter}' == ' committedInformationRate'
    ...    Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[2]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${cbs_value}    Run Keyword If    '${bandwidthparameter}' == ' committedBurstSize'    Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[3]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${eir_value}    Run Keyword If    '${bandwidthparameter}' == ' exceededInformationRate'   Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[4]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${ebs_value}    Run Keyword If    '${bandwidthparameter}' == ' exceededBurstSize'    Set Variable    ${value}
    ${limiting_BW}=    Evaluate    ${cir_value}+${eir_value}
    [Return]    ${limiting_BW}
