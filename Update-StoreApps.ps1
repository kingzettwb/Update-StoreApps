#Script name: Update-StoreApps.ps1
#Author: Bill Kingzett (NIH\NHGRI)
#Date: 2025-10-16
#Description:
#Retrieves the latest version of installed apps from Microsoft as well as its dependencies.
#Can install/stage the downloaded packages. Useful when Update-StateRepository.ps1 is run afterwards
#This script is intended to be run as System or Admin.
#
#Arguments:
#[string]SoftwareFamily (optional): The Package Family Name of the package to update. Leaving this options blank will update all packages
#[string]LogLocation: Path to the log file detailing actions taking during the script. Actions are written to the log as they're generated, but no action is taken until the SQL file is run near the end
#[string]DownloadPath: Path to a staging location to store downloaded apps.
#[bool]Install: $True installs the packages and deletes them when finished. $False only downloads them.
#[switch]Verbose: Adds some additional logging

[CmdletBinding()]
param(
	[string] $SoftwareFamily="",
    [string] $LogLocation = "C:\ProgramData\Logs\DownloadStoreUpdates.log",
    [string] $DownloadPath = "C:\Temp\StoreApps",
    [bool] $Install = $true
)

if (!(Get-Item -path "$($LogLocation.Substring(0, $LogLocation.LastIndexOf('\')))")) {New-Item -Path "$($LogLocation.Substring(0, $LogLocation.LastIndexOf('\')))" -ItemType Directory}
Start-Transcript -Path $LogLocation -Append

#https://github.com/LSPosed/MagiskOnWSALocal/commit/615c125030e3f448e4ac5d34f812cd4c0027cc06#diff-43d49eb4c2622087ea8885472c2ff0894e897f95f7c7fe53aad4ecb3b7a6b9a6L19
$wuidRequestXml_original = @"
<s:Envelope xmlns:a="http://www.w3.org/2005/08/addressing"
	xmlns:s="http://www.w3.org/2003/05/soap-envelope">
	<s:Header>
		<a:Action s:mustUnderstand="1">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/SyncUpdates</a:Action>
		<a:MessageID>urn:uuid:175df68c-4b91-41ee-b70b-f2208c65438e</a:MessageID>
		<a:To s:mustUnderstand="1">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx</a:To>
		<o:Security s:mustUnderstand="1"
			xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
			<Timestamp xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
				<Created>2017-08-05T02:03:05.038Z</Created>
				<Expires>2017-08-05T02:08:05.038Z</Expires>
			</Timestamp>
			<wuws:WindowsUpdateTicketsToken wsu:id="ClientMSA"
				xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
				xmlns:wuws="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
				<TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
					<Device>dAA9AEUAdwBBAHcAQQBzAE4AMwBCAEEAQQBVADEAYgB5AHMAZQBtAGIAZQBEAFYAQwArADMAZgBtADcAbwBXAHkASAA3AGIAbgBnAEcAWQBtAEEAQQBMAGoAbQBqAFYAVQB2AFEAYwA0AEsAVwBFAC8AYwBDAEwANQBYAGUANABnAHYAWABkAGkAegBHAGwAZABjADEAZAAvAFcAeQAvAHgASgBQAG4AVwBRAGUAYwBtAHYAbwBjAGkAZwA5AGoAZABwAE4AawBIAG0AYQBzAHAAVABKAEwARAArAFAAYwBBAFgAbQAvAFQAcAA3AEgAagBzAEYANAA0AEgAdABsAC8AMQBtAHUAcgAwAFMAdQBtAG8AMABZAGEAdgBqAFIANwArADQAcABoAC8AcwA4ADEANgBFAFkANQBNAFIAbQBnAFIAQwA2ADMAQwBSAEoAQQBVAHYAZgBzADQAaQB2AHgAYwB5AEwAbAA2AHoAOABlAHgAMABrAFgAOQBPAHcAYQB0ADEAdQBwAFMAOAAxAEgANgA4AEEASABzAEoAegBnAFQAQQBMAG8AbgBBADIAWQBBAEEAQQBpAGcANQBJADMAUQAvAFYASABLAHcANABBAEIAcQA5AFMAcQBhADEAQgA4AGsAVQAxAGEAbwBLAEEAdQA0AHYAbABWAG4AdwBWADMAUQB6AHMATgBtAEQAaQBqAGgANQBkAEcAcgBpADgAQQBlAEUARQBWAEcAbQBXAGgASQBCAE0AUAAyAEQAVwA0ADMAZABWAGkARABUAHoAVQB0AHQARQBMAEgAaABSAGYAcgBhAGIAWgBsAHQAQQBUAEUATABmAHMARQBGAFUAYQBRAFMASgB4ADUAeQBRADgAagBaAEUAZQAyAHgANABCADMAMQB2AEIAMgBqAC8AUgBLAGEAWQAvAHEAeQB0AHoANwBUAHYAdAB3AHQAagBzADYAUQBYAEIAZQA4AHMAZwBJAG8AOQBiADUAQQBCADcAOAAxAHMANgAvAGQAUwBFAHgATgBEAEQAYQBRAHoAQQBYAFAAWABCAFkAdQBYAFEARQBzAE8AegA4AHQAcgBpAGUATQBiAEIAZQBUAFkAOQBiAG8AQgBOAE8AaQBVADcATgBSAEYAOQAzAG8AVgArAFYAQQBiAGgAcAAwAHAAUgBQAFMAZQBmAEcARwBPAHEAdwBTAGcANwA3AHMAaAA5AEoASABNAHAARABNAFMAbgBrAHEAcgAyAGYARgBpAEMAUABrAHcAVgBvAHgANgBuAG4AeABGAEQAbwBXAC8AYQAxAHQAYQBaAHcAegB5AGwATABMADEAMgB3AHUAYgBtADUAdQBtAHAAcQB5AFcAYwBLAFIAagB5AGgAMgBKAFQARgBKAFcANQBnAFgARQBJADUAcAA4ADAARwB1ADIAbgB4AEwAUgBOAHcAaQB3AHIANwBXAE0AUgBBAFYASwBGAFcATQBlAFIAegBsADkAVQBxAGcALwBwAFgALwB2AGUATAB3AFMAawAyAFMAUwBIAGYAYQBLADYAagBhAG8AWQB1AG4AUgBHAHIAOABtAGIARQBvAEgAbABGADYASgBDAGEAYQBUAEIAWABCAGMAdgB1AGUAQwBKAG8AOQA4AGgAUgBBAHIARwB3ADQAKwBQAEgAZQBUAGIATgBTAEUAWABYAHoAdgBaADYAdQBXADUARQBBAGYAZABaAG0AUwA4ADgAVgBKAGMAWgBhAEYASwA3AHgAeABnADAAdwBvAG4ANwBoADAAeABDADYAWgBCADAAYwBZAGoATAByAC8ARwBlAE8AegA5AEcANABRAFUASAA5AEUAawB5ADAAZAB5AEYALwByAGUAVQAxAEkAeQBpAGEAcABwAGgATwBQADgAUwAyAHQANABCAHIAUABaAFgAVAB2AEMAMABQADcAegBPACsAZgBHAGsAeABWAG0AKwBVAGYAWgBiAFEANQA1AHMAdwBFAD0AJgBwAD0A</Device>
				</TicketType>
			</wuws:WindowsUpdateTicketsToken>
		</o:Security>
	</s:Header>
	<s:Body>
		<SyncUpdates xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
			<cookie>
				<Expiration>{CookieExpiration}</Expiration>
				<EncryptedData>{CookieData}</EncryptedData>
			</cookie>
			<parameters>
				<ExpressQuery>false</ExpressQuery>
				<InstalledNonLeafUpdateIDs>
					<int>1</int>
					<int>2</int>
					<int>3</int>
					<int>11</int>
					<int>19</int>
					<int>544</int>
					<int>549</int>
					<int>2359974</int>
					<int>2359977</int>
					<int>5169044</int>
					<int>8788830</int>
					<int>23110993</int>
					<int>23110994</int>
					<int>54341900</int>
					<int>54343656</int>
					<int>59830006</int>
					<int>59830007</int>
					<int>59830008</int>
					<int>60484010</int>
					<int>62450018</int>
					<int>62450019</int>
					<int>62450020</int>
					<int>66027979</int>
					<int>66053150</int>
					<int>97657898</int>
					<int>98822896</int>
					<int>98959022</int>
					<int>98959023</int>
					<int>98959024</int>
					<int>98959025</int>
					<int>98959026</int>
					<int>104433538</int>
					<int>104900364</int>
					<int>105489019</int>
					<int>117765322</int>
					<int>129905029</int>
					<int>130040031</int>
					<int>132387090</int>
					<int>132393049</int>
					<int>133399034</int>
					<int>138537048</int>
					<int>140377312</int>
					<int>143747671</int>
					<int>158941041</int>
					<int>158941042</int>
					<int>158941043</int>
					<int>158941044</int>
					<int>159123858</int>
					<int>159130928</int>
					<int>164836897</int>
					<int>164847386</int>
					<int>164848327</int>
					<int>164852241</int>
					<int>164852246</int>
					<int>164852252</int>
					<int>164852253</int>
				</InstalledNonLeafUpdateIDs>
				<OtherCachedUpdateIDs>
					<int>10</int>
					<int>17</int>
					<int>2359977</int>
					<int>5143990</int>
					<int>5169043</int>
					<int>5169047</int>
					<int>8806526</int>
					<int>9125350</int>
					<int>9154769</int>
					<int>10809856</int>
					<int>23110995</int>
					<int>23110996</int>
					<int>23110999</int>
					<int>23111000</int>
					<int>23111001</int>
					<int>23111002</int>
					<int>23111003</int>
					<int>23111004</int>
					<int>24513870</int>
					<int>28880263</int>
					<int>30077688</int>
					<int>30486944</int>
					<int>30526991</int>
					<int>30528442</int>
					<int>30530496</int>
					<int>30530501</int>
					<int>30530504</int>
					<int>30530962</int>
					<int>30535326</int>
					<int>30536242</int>
					<int>30539913</int>
					<int>30545142</int>
					<int>30545145</int>
					<int>30545488</int>
					<int>30546212</int>
					<int>30547779</int>
					<int>30548797</int>
					<int>30548860</int>
					<int>30549262</int>
					<int>30551160</int>
					<int>30551161</int>
					<int>30551164</int>
					<int>30553016</int>
					<int>30553744</int>
					<int>30554014</int>
					<int>30559008</int>
					<int>30559011</int>
					<int>30560006</int>
					<int>30560011</int>
					<int>30561006</int>
					<int>30563261</int>
					<int>30565215</int>
					<int>30578059</int>
					<int>30664998</int>
					<int>30677904</int>
					<int>30681618</int>
					<int>30682195</int>
					<int>30685055</int>
					<int>30702579</int>
					<int>30708772</int>
					<int>30709591</int>
					<int>30711304</int>
					<int>30715418</int>
					<int>30720106</int>
					<int>30720273</int>
					<int>30732075</int>
					<int>30866952</int>
					<int>30866964</int>
					<int>30870749</int>
					<int>30877852</int>
					<int>30878437</int>
					<int>30890151</int>
					<int>30892149</int>
					<int>30990917</int>
					<int>31049444</int>
					<int>31190936</int>
					<int>31196961</int>
					<int>31197811</int>
					<int>31198836</int>
					<int>31202713</int>
					<int>31203522</int>
					<int>31205442</int>
					<int>31205557</int>
					<int>31207585</int>
					<int>31208440</int>
					<int>31208451</int>
					<int>31209591</int>
					<int>31210536</int>
					<int>31211625</int>
					<int>31212713</int>
					<int>31213588</int>
					<int>31218518</int>
					<int>31219420</int>
					<int>31220279</int>
					<int>31220302</int>
					<int>31222086</int>
					<int>31227080</int>
					<int>31229030</int>
					<int>31238236</int>
					<int>31254198</int>
					<int>31258008</int>
					<int>36436779</int>
					<int>36437850</int>
					<int>36464012</int>
					<int>41916569</int>
					<int>47249982</int>
					<int>47283134</int>
					<int>58577027</int>
					<int>58578040</int>
					<int>58578041</int>
					<int>58628920</int>
					<int>59107045</int>
					<int>59125697</int>
					<int>59142249</int>
					<int>60466586</int>
					<int>60478936</int>
					<int>66450441</int>
					<int>66467021</int>
					<int>66479051</int>
					<int>75202978</int>
					<int>77436021</int>
					<int>77449129</int>
					<int>85159569</int>
					<int>90199702</int>
					<int>90212090</int>
					<int>96911147</int>
					<int>97110308</int>
					<int>98528428</int>
					<int>98665206</int>
					<int>98837995</int>
					<int>98842922</int>
					<int>98842977</int>
					<int>98846632</int>
					<int>98866485</int>
					<int>98874250</int>
					<int>98879075</int>
					<int>98904649</int>
					<int>98918872</int>
					<int>98945691</int>
					<int>98959458</int>
					<int>98984707</int>
					<int>100220125</int>
					<int>100238731</int>
					<int>100662329</int>
					<int>100795834</int>
					<int>100862457</int>
					<int>103124811</int>
					<int>103348671</int>
					<int>104369981</int>
					<int>104372472</int>
					<int>104385324</int>
					<int>104465831</int>
					<int>104465834</int>
					<int>104467697</int>
					<int>104473368</int>
					<int>104482267</int>
					<int>104505005</int>
					<int>104523840</int>
					<int>104550085</int>
					<int>104558084</int>
					<int>104659441</int>
					<int>104659675</int>
					<int>104664678</int>
					<int>104668274</int>
					<int>104671092</int>
					<int>104673242</int>
					<int>104674239</int>
					<int>104679268</int>
					<int>104686047</int>
					<int>104698649</int>
					<int>104751469</int>
					<int>104752478</int>
					<int>104755145</int>
					<int>104761158</int>
					<int>104762266</int>
					<int>104786484</int>
					<int>104853747</int>
					<int>104873258</int>
					<int>104983051</int>
					<int>105063056</int>
					<int>105116588</int>
					<int>105178523</int>
					<int>105318602</int>
					<int>105362613</int>
					<int>105364552</int>
					<int>105368563</int>
					<int>105369591</int>
					<int>105370746</int>
					<int>105373503</int>
					<int>105373615</int>
					<int>105376634</int>
					<int>105377546</int>
					<int>105378752</int>
					<int>105379574</int>
					<int>105381626</int>
					<int>105382587</int>
					<int>105425313</int>
					<int>105495146</int>
					<int>105862607</int>
					<int>105939029</int>
					<int>105995585</int>
					<int>106017178</int>
					<int>106129726</int>
					<int>106768485</int>
					<int>107825194</int>
					<int>111906429</int>
					<int>115121473</int>
					<int>115578654</int>
					<int>116630363</int>
					<int>117835105</int>
					<int>117850671</int>
					<int>118638500</int>
					<int>118662027</int>
					<int>118872681</int>
					<int>118873829</int>
					<int>118879289</int>
					<int>118889092</int>
					<int>119501720</int>
					<int>119551648</int>
					<int>119569538</int>
					<int>119640702</int>
					<int>119667998</int>
					<int>119674103</int>
					<int>119697201</int>
					<int>119706266</int>
					<int>119744627</int>
					<int>119773746</int>
					<int>120072697</int>
					<int>120144309</int>
					<int>120214154</int>
					<int>120357027</int>
					<int>120392612</int>
					<int>120399120</int>
					<int>120553945</int>
					<int>120783545</int>
					<int>120797092</int>
					<int>120881676</int>
					<int>120889689</int>
					<int>120999554</int>
					<int>121168608</int>
					<int>121268830</int>
					<int>121341838</int>
					<int>121729951</int>
					<int>121803677</int>
					<int>122165810</int>
					<int>125408034</int>
					<int>127293130</int>
					<int>127566683</int>
					<int>127762067</int>
					<int>127861893</int>
					<int>128571722</int>
					<int>128647535</int>
					<int>128698922</int>
					<int>128701748</int>
					<int>128771507</int>
					<int>129037212</int>
					<int>129079800</int>
					<int>129175415</int>
					<int>129317272</int>
					<int>129319665</int>
					<int>129365668</int>
					<int>129378095</int>
					<int>129424803</int>
					<int>129590730</int>
					<int>129603714</int>
					<int>129625954</int>
					<int>129692391</int>
					<int>129714980</int>
					<int>129721097</int>
					<int>129886397</int>
					<int>129968371</int>
					<int>129972243</int>
					<int>130009862</int>
					<int>130033651</int>
					<int>130040030</int>
					<int>130040032</int>
					<int>130040033</int>
					<int>130091954</int>
					<int>130100640</int>
					<int>130131267</int>
					<int>130131921</int>
					<int>130144837</int>
					<int>130171030</int>
					<int>130172071</int>
					<int>130197218</int>
					<int>130212435</int>
					<int>130291076</int>
					<int>130402427</int>
					<int>130405166</int>
					<int>130676169</int>
					<int>130698471</int>
					<int>130713390</int>
					<int>130785217</int>
					<int>131396908</int>
					<int>131455115</int>
					<int>131682095</int>
					<int>131689473</int>
					<int>131701956</int>
					<int>132142800</int>
					<int>132525441</int>
					<int>132765492</int>
					<int>132801275</int>
					<int>133399034</int>
					<int>134522926</int>
					<int>134524022</int>
					<int>134528994</int>
					<int>134532942</int>
					<int>134536993</int>
					<int>134538001</int>
					<int>134547533</int>
					<int>134549216</int>
					<int>134549317</int>
					<int>134550159</int>
					<int>134550214</int>
					<int>134550232</int>
					<int>134551154</int>
					<int>134551207</int>
					<int>134551390</int>
					<int>134553171</int>
					<int>134553237</int>
					<int>134554199</int>
					<int>134554227</int>
					<int>134555229</int>
					<int>134555240</int>
					<int>134556118</int>
					<int>134557078</int>
					<int>134560099</int>
					<int>134560287</int>
					<int>134562084</int>
					<int>134562180</int>
					<int>134563287</int>
					<int>134565083</int>
					<int>134566130</int>
					<int>134568111</int>
					<int>134624737</int>
					<int>134666461</int>
					<int>134672998</int>
					<int>134684008</int>
					<int>134916523</int>
					<int>135100527</int>
					<int>135219410</int>
					<int>135222083</int>
					<int>135306997</int>
					<int>135463054</int>
					<int>135779456</int>
					<int>135812968</int>
					<int>136097030</int>
					<int>136131333</int>
					<int>136146907</int>
					<int>136157556</int>
					<int>136320962</int>
					<int>136450641</int>
					<int>136466000</int>
					<int>136745792</int>
					<int>136761546</int>
					<int>136840245</int>
					<int>138160034</int>
					<int>138181244</int>
					<int>138210071</int>
					<int>138210107</int>
					<int>138232200</int>
					<int>138237088</int>
					<int>138277547</int>
					<int>138287133</int>
					<int>138306991</int>
					<int>138324625</int>
					<int>138341916</int>
					<int>138372035</int>
					<int>138372036</int>
					<int>138375118</int>
					<int>138378071</int>
					<int>138380128</int>
					<int>138380194</int>
					<int>138534411</int>
					<int>138618294</int>
					<int>138931764</int>
					<int>139536037</int>
					<int>139536038</int>
					<int>139536039</int>
					<int>139536040</int>
					<int>140367832</int>
					<int>140406050</int>
					<int>140421668</int>
					<int>140422973</int>
					<int>140423713</int>
					<int>140436348</int>
					<int>140483470</int>
					<int>140615715</int>
					<int>140802803</int>
					<int>140896470</int>
					<int>141189437</int>
					<int>141192744</int>
					<int>141382548</int>
					<int>141461680</int>
					<int>141624996</int>
					<int>141627135</int>
					<int>141659139</int>
					<int>141872038</int>
					<int>141993721</int>
					<int>142006413</int>
					<int>142045136</int>
					<int>142095667</int>
					<int>142227273</int>
					<int>142250480</int>
					<int>142518788</int>
					<int>142544931</int>
					<int>142546314</int>
					<int>142555433</int>
					<int>142653044</int>
					<int>143191852</int>
					<int>143258496</int>
					<int>143299722</int>
					<int>143331253</int>
					<int>143432462</int>
					<int>143632431</int>
					<int>143695326</int>
					<int>144219522</int>
					<int>144590916</int>
					<int>145410436</int>
					<int>146720405</int>
					<int>150810438</int>
					<int>151258773</int>
					<int>151315554</int>
					<int>151400090</int>
					<int>151429441</int>
					<int>151439617</int>
					<int>151453617</int>
					<int>151466296</int>
					<int>151511132</int>
					<int>151636561</int>
					<int>151823192</int>
					<int>151827116</int>
					<int>151850642</int>
					<int>152016572</int>
					<int>153111675</int>
					<int>153114652</int>
					<int>153123147</int>
					<int>153267108</int>
					<int>153389799</int>
					<int>153395366</int>
					<int>153718608</int>
					<int>154171028</int>
					<int>154315227</int>
					<int>154559688</int>
					<int>154978771</int>
					<int>154979742</int>
					<int>154985773</int>
					<int>154989370</int>
					<int>155044852</int>
					<int>155065458</int>
					<int>155578573</int>
					<int>156403304</int>
					<int>159085959</int>
					<int>159776047</int>
					<int>159816630</int>
					<int>160733048</int>
					<int>160733049</int>
					<int>160733050</int>
					<int>160733051</int>
					<int>160733056</int>
					<int>164824922</int>
					<int>164824924</int>
					<int>164824926</int>
					<int>164824930</int>
					<int>164831646</int>
					<int>164831647</int>
					<int>164831648</int>
					<int>164831650</int>
					<int>164835050</int>
					<int>164835051</int>
					<int>164835052</int>
					<int>164835056</int>
					<int>164835057</int>
					<int>164835059</int>
					<int>164836898</int>
					<int>164836899</int>
					<int>164836900</int>
					<int>164845333</int>
					<int>164845334</int>
					<int>164845336</int>
					<int>164845337</int>
					<int>164845341</int>
					<int>164845342</int>
					<int>164845345</int>
					<int>164845346</int>
					<int>164845349</int>
					<int>164845350</int>
					<int>164845353</int>
					<int>164845355</int>
					<int>164845358</int>
					<int>164845361</int>
					<int>164845364</int>
					<int>164847387</int>
					<int>164847388</int>
					<int>164847389</int>
					<int>164847390</int>
					<int>164848328</int>
					<int>164848329</int>
					<int>164848330</int>
					<int>164849448</int>
					<int>164849449</int>
					<int>164849451</int>
					<int>164849452</int>
					<int>164849454</int>
					<int>164849455</int>
					<int>164849457</int>
					<int>164849461</int>
					<int>164850219</int>
					<int>164850220</int>
					<int>164850222</int>
					<int>164850223</int>
					<int>164850224</int>
					<int>164850226</int>
					<int>164850227</int>
					<int>164850228</int>
					<int>164850229</int>
					<int>164850231</int>
					<int>164850236</int>
					<int>164850237</int>
					<int>164850240</int>
					<int>164850242</int>
					<int>164850243</int>
					<int>164852242</int>
					<int>164852243</int>
					<int>164852244</int>
					<int>164852247</int>
					<int>164852248</int>
					<int>164852249</int>
					<int>164852250</int>
					<int>164852251</int>
					<int>164852254</int>
					<int>164852256</int>
					<int>164852257</int>
					<int>164852258</int>
					<int>164852259</int>
					<int>164852260</int>
					<int>164852261</int>
					<int>164852262</int>
					<int>164853061</int>
					<int>164853063</int>
					<int>164853071</int>
					<int>164853072</int>
					<int>164853075</int>
					<int>168118980</int>
					<int>168118981</int>
					<int>168118983</int>
					<int>168118984</int>
					<int>168180375</int>
					<int>168180376</int>
					<int>168180378</int>
					<int>168180379</int>
					<int>168270830</int>
					<int>168270831</int>
					<int>168270833</int>
					<int>168270834</int>
					<int>168270835</int>
				</OtherCachedUpdateIDs>
				<SkipSoftwareSync>false</SkipSoftwareSync>
				<NeedTwoGroupOutOfScopeUpdates>false</NeedTwoGroupOutOfScopeUpdates>
				<FilterAppCategoryIds>
					<CategoryIdentifier>
						<Id>{wuCategoryId}</Id>
					</CategoryIdentifier>
				</FilterAppCategoryIds>
				<TreatAppCategoryIdsAsInstalled>true</TreatAppCategoryIdsAsInstalled>
				<AlsoPerformRegularSync>false</AlsoPerformRegularSync>
				<ComputerSpec/>
				<ExtendedUpdateInfoParameters>
					<XmlUpdateFragmentTypes>
						<XmlUpdateFragmentType>Extended</XmlUpdateFragmentType>
					</XmlUpdateFragmentTypes>
					<Locales>
						<string>en-US</string>
						<string>en</string>
					</Locales>
				</ExtendedUpdateInfoParameters>
				<ClientPreferredLanguages>
					<string>en-US</string>
				</ClientPreferredLanguages>
				<ProductsParameters>
					<SyncCurrentVersionOnly>true</SyncCurrentVersionOnly>
					<DeviceAttributes>BranchReadinessLevel=CB;CurrentBranch=rs_prerelease;OEMModel=Virtual Machine;FlightRing=retail;AttrDataVer=21;SystemManufacturer=Microsoft Corporation;InstallLanguage=en-US;OSUILocale=en-US;InstallationType=Client;FlightingBranchName=external;FirmwareVersion=Hyper-V UEFI Release v2.5;SystemProductName=Virtual Machine;OSSkuId=48;FlightContent=Branch;App=WU;OEMName_Uncleaned=Microsoft Corporation;AppVer=10.0.22621.900;OSArchitecture=AMD64;SystemSKU=None;UpdateManagementGroup=2;IsFlightingEnabled=1;IsDeviceRetailDemo=0;TelemetryLevel=3;OSVersion=10.0.22621.900;DeviceFamily=Windows.Desktop;</DeviceAttributes>
					<CallerAttributes>Interactive=1;IsSeeker=0;</CallerAttributes>
					<Products/>
				</ProductsParameters>
			</parameters>
		</SyncUpdates>
	</s:Body>
</s:Envelope>
"@

$FE3FileURLXML = @'
<s:Envelope xmlns:a="http://www.w3.org/2005/08/addressing"
	xmlns:s="http://www.w3.org/2003/05/soap-envelope">
	<s:Header>
		<a:Action s:mustUnderstand="1">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/GetExtendedUpdateInfo2</a:Action>
		<a:MessageID>urn:uuid:2cc99c2e-3b3e-4fb1-9e31-0cd30e6f43a0</a:MessageID>
		<a:To s:mustUnderstand="1">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured</a:To>
		<o:Security s:mustUnderstand="1"
			xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
			<Timestamp xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
				<Created>2017-08-01T00:29:01.868Z</Created>
				<Expires>2017-08-01T00:34:01.868Z</Expires>
			</Timestamp>
			<wuws:WindowsUpdateTicketsToken wsu:id="ClientMSA"
				xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
				xmlns:wuws="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
				<TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
					<Device>dAA9AEUAdwBBAHcAQQBzAE4AMwBCAEEAQQBVADEAYgB5AHMAZQBtAGIAZQBEAFYAQwArADMAZgBtADcAbwBXAHkASAA3AGIAbgBnAEcAWQBtAEEAQQBMAGoAbQBqAFYAVQB2AFEAYwA0AEsAVwBFAC8AYwBDAEwANQBYAGUANABnAHYAWABkAGkAegBHAGwAZABjADEAZAAvAFcAeQAvAHgASgBQAG4AVwBRAGUAYwBtAHYAbwBjAGkAZwA5AGoAZABwAE4AawBIAG0AYQBzAHAAVABKAEwARAArAFAAYwBBAFgAbQAvAFQAcAA3AEgAagBzAEYANAA0AEgAdABsAC8AMQBtAHUAcgAwAFMAdQBtAG8AMABZAGEAdgBqAFIANwArADQAcABoAC8AcwA4ADEANgBFAFkANQBNAFIAbQBnAFIAQwA2ADMAQwBSAEoAQQBVAHYAZgBzADQAaQB2AHgAYwB5AEwAbAA2AHoAOABlAHgAMABrAFgAOQBPAHcAYQB0ADEAdQBwAFMAOAAxAEgANgA4AEEASABzAEoAegBnAFQAQQBMAG8AbgBBADIAWQBBAEEAQQBpAGcANQBJADMAUQAvAFYASABLAHcANABBAEIAcQA5AFMAcQBhADEAQgA4AGsAVQAxAGEAbwBLAEEAdQA0AHYAbABWAG4AdwBWADMAUQB6AHMATgBtAEQAaQBqAGgANQBkAEcAcgBpADgAQQBlAEUARQBWAEcAbQBXAGgASQBCAE0AUAAyAEQAVwA0ADMAZABWAGkARABUAHoAVQB0AHQARQBMAEgAaABSAGYAcgBhAGIAWgBsAHQAQQBUAEUATABmAHMARQBGAFUAYQBRAFMASgB4ADUAeQBRADgAagBaAEUAZQAyAHgANABCADMAMQB2AEIAMgBqAC8AUgBLAGEAWQAvAHEAeQB0AHoANwBUAHYAdAB3AHQAagBzADYAUQBYAEIAZQA4AHMAZwBJAG8AOQBiADUAQQBCADcAOAAxAHMANgAvAGQAUwBFAHgATgBEAEQAYQBRAHoAQQBYAFAAWABCAFkAdQBYAFEARQBzAE8AegA4AHQAcgBpAGUATQBiAEIAZQBUAFkAOQBiAG8AQgBOAE8AaQBVADcATgBSAEYAOQAzAG8AVgArAFYAQQBiAGgAcAAwAHAAUgBQAFMAZQBmAEcARwBPAHEAdwBTAGcANwA3AHMAaAA5AEoASABNAHAARABNAFMAbgBrAHEAcgAyAGYARgBpAEMAUABrAHcAVgBvAHgANgBuAG4AeABGAEQAbwBXAC8AYQAxAHQAYQBaAHcAegB5AGwATABMADEAMgB3AHUAYgBtADUAdQBtAHAAcQB5AFcAYwBLAFIAagB5AGgAMgBKAFQARgBKAFcANQBnAFgARQBJADUAcAA4ADAARwB1ADIAbgB4AEwAUgBOAHcAaQB3AHIANwBXAE0AUgBBAFYASwBGAFcATQBlAFIAegBsADkAVQBxAGcALwBwAFgALwB2AGUATAB3AFMAawAyAFMAUwBIAGYAYQBLADYAagBhAG8AWQB1AG4AUgBHAHIAOABtAGIARQBvAEgAbABGADYASgBDAGEAYQBUAEIAWABCAGMAdgB1AGUAQwBKAG8AOQA4AGgAUgBBAHIARwB3ADQAKwBQAEgAZQBUAGIATgBTAEUAWABYAHoAdgBaADYAdQBXADUARQBBAGYAZABaAG0AUwA4ADgAVgBKAGMAWgBhAEYASwA3AHgAeABnADAAdwBvAG4ANwBoADAAeABDADYAWgBCADAAYwBZAGoATAByAC8ARwBlAE8AegA5AEcANABRAFUASAA5AEUAawB5ADAAZAB5AEYALwByAGUAVQAxAEkAeQBpAGEAcABwAGgATwBQADgAUwAyAHQANABCAHIAUABaAFgAVAB2AEMAMABQADcAegBPACsAZgBHAGsAeABWAG0AKwBVAGYAWgBiAFEANQA1AHMAdwBFAD0AJgBwAD0A</Device>
				</TicketType>
			</wuws:WindowsUpdateTicketsToken>
		</o:Security>
	</s:Header>
	<s:Body>
		<GetExtendedUpdateInfo2 xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
			<updateIDs>
				<UpdateIdentity>
					<UpdateID>{}</UpdateID>
					<RevisionNumber>{}</RevisionNumber>
				</UpdateIdentity>
			</updateIDs>
			<infoTypes>
				<XmlUpdateFragmentType>FileUrl</XmlUpdateFragmentType>
				<XmlUpdateFragmentType>FileDecryption</XmlUpdateFragmentType>
			</infoTypes>
			<deviceAttributes>BranchReadinessLevel=CB;CurrentBranch=rs_prerelease;OEMModel=Virtual Machine;FlightRing=retail;AttrDataVer=21;SystemManufacturer=Microsoft Corporation;InstallLanguage=en-US;OSUILocale=en-US;InstallationType=Client;FlightingBranchName=external;FirmwareVersion=Hyper-V UEFI Release v2.5;SystemProductName=Virtual Machine;OSSkuId=48;FlightContent=Branch;App=WU;OEMName_Uncleaned=Microsoft Corporation;AppVer=10.0.22621.900;OSArchitecture=AMD64;SystemSKU=None;UpdateManagementGroup=2;IsFlightingEnabled=1;IsDeviceRetailDemo=0;TelemetryLevel=3;OSVersion=10.0.22621.900;DeviceFamily=Windows.Desktop;</deviceAttributes>
		</GetExtendedUpdateInfo2>
	</s:Body>
</s:Envelope>
'@

#From ChatGPT with some tweaking by me to optimize.
#Expands downloaded package to check for dependencies
function Get-MSIXDependenciesFromFile {
  param([Parameter(Mandatory)][string]$Path)

  $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
    "x86" { "x86" }
    { @("x64", "amd64") -contains $_ } { "x64" }
    "arm" { "arm" }
    "arm64" { "arm64" }
    default { "neutral" }
  }

  $full = (Resolve-Path $Path).Path
  $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
  $tmp = Join-Path $env:TEMP ("msix_" + [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName())))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null

  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($full, $tmp)

    $results = @()
    if ($ext -in '.msix','.appx') {
      $manifest = Join-Path $tmp 'AppxManifest.xml'
      if (Test-Path $manifest) {
        [xml]$xml = Get-Content $manifest
        $results += [pscustomobject]@{Package = $xml.GetElementsByTagName("PackageDependency") | Select Name, MinVersion; OS = $xml.GetElementsByTagName("TargetDeviceFamily") | Where {$_.name -eq "Windows.Desktop" -or $_.name -eq "Windows.Universal"} | Sort-Object -Property MinVersion -Descending | Select MinVersion -ExpandProperty MinVersion -First 1}
      }
    } else {
      # bundle: parse every inner .appx/.msix
      Get-ChildItem -Path $tmp -Recurse -Include *$architecture.msix,*$architecture.appx -Exclude "*language*", "*scale*" | ForEach-Object {
        $pkgTmp = Join-Path $tmp ("unpack_" + [IO.Path]::GetFileNameWithoutExtension($_.Name))
        New-Item -ItemType Directory -Path $pkgTmp | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, $pkgTmp)
        $manifest = Join-Path $pkgTmp 'AppxManifest.xml'
        if (Test-Path $manifest) {
          [xml]$manifestxml = Get-Content $manifest
          $results += [pscustomobject]@{Package = $manifestxml.GetElementsByTagName("PackageDependency") | Select Name, MinVersion; OS = $manifestxml.GetElementsByTagName("TargetDeviceFamily") | Where {$_.name -eq "Windows.Desktop" -or $_.name -eq "Windows.Universal"} | Sort-Object -Property MinVersion -Descending | Select MinVersion -ExpandProperty MinVersion -First 1}
        }
      }
    }
    $results
  } finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  }
}

#Takes: Product ID from Get-ProductID
#Returns: Windows Update Category ID
function Get-wuCategoryID ([string]$ProductID)
{
    $market = "US"
    $locale = "en-us"
    $deviceFamily = "Windows.Desktop"
    $jsonUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/$ProductId" + "?market=$market&locale=$locale&deviceFamily=$deviceFamily"
    #$jsonUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/9pcfs5b6t72h"

    $jsonResponse = Invoke-RestMethod -Uri $jsonUrl -Method Get
    $FulfillmentString = (($jsonResponse.Payload.Skus | Where SkuType -EQ "full").FulfillmentData).Trim('{','}').Split(',')
    #Make sure there's only ever 1
    foreach ($string in $FulfillmentString)
    {
        if ($string -like "*WuCategoryID*")
        {
            $wuCategoryId = $String.Split(':')[1].Trim('"')
        }
    }
        $wuCategoryId
}

function Wildcard-toRegex($WildcardString) #Takes a string or array of strings, escapes them and translates * to the regex wildcard equivalent
{ #Also allows you to match on multiple strings
    $Result = @()
    $WildcardString | ForEach-Object {
    $_ = $_.Trim('*')
    $_ = [regex]::Escape($_)
    $_ = $_.Insert(0,'(')
    $_ += ')'
    $_ = $_.Replace('\*','.*?')
    $Result += $_
    }
    $Result = $Result -join '|'
    if ($Result -eq '|'){$Result = $null}  #Fixes error condition where it may return only | if $WildcardString is empty, which is everything
    return $Result
}

#Takes: Package Family Name or App name, with Package Family Name given priority if both are given. If neither are given, search all installed apps
#Returns: Product ID and package name
function Get-ProductID {
    param(
	    [string[]] $PackageFamilyName=$null,
        [string[]] $Name=$null
    )
    if ($PackageFamilyName -ne $null) { $installedapps = Get-appxpackage -AllUsers -PackageTypeFilter All | Where { $_.PackageFamilyName -match (Wildcard-toRegex $PackageFamilyName)} | Select PackageFamilyName, Name -Unique }
    elseif ($Name -ne $null) {  $installedapps = Get-appxpackage -AllUsers -PackageTypeFilter All | Where { $_.Name -match (Wildcard-toRegex $Name)} | Select PackageFamilyName, Name -Unique }
    else { $installedapps = Get-appxpackage -AllUsers -PackageTypeFilter All | Select PackageFamilyName, Name -Unique }


    $ProductIDs = @()
    foreach ($installed in $installedapps)
    {
        #Pause to try to avoid rate limiting
        Start-Sleep -Milliseconds 500
        #Old, found by searching for the MS Store website with dev tools open. Newer, but didn't allow much flexibility#$URI = "https://apps.microsoft.com/api/products/search?query={Query}&mediaType=Apps&age=all&category=all&gl=US&hl=en-US"
        #Found new URI here: https://github.com/StoreDev/StoreLib/blob/Public/StoreLib/Models/Endpoint.cs and https://github.com/StoreDev/StoreLib/blob/Public/StoreLib/Utilities/Utilities.cs
        $URI = "https://displaycatalog.mp.microsoft.com/v7.0/products/lookup?alternateId=PackageFamilyName&Value={PFN}&market=US&languages=en-US&fieldsTemplate=Details"
        $packageFN = $installed.PackageFamilyName
        $packageName = $installed.Name
        $ProductID = $null
        $SearchURI = $URI -replace '{.*?}',"$packageFN"
        try{ $response = Invoke-RestMethod $SearchURI -Method Get -ErrorAction SilentlyContinue }
        catch {
            Write-Warning "Product ID lookup for $packageName failed with error: $($Error[0].exception). Retrying..."
            Start-Sleep -Seconds 1
            $response = Invoke-RestMethod $SearchURI -Method Get -ErrorAction SilentlyContinue
            }
        if ($response.BigIds -ne $null)
        {
            $ProductID = $response.BigIds
            $ProductIDs += [pscustomobject]@{ID = $ProductID; Name = $packageName}
            Write-Host "Found $ProductID for $packageName"
        }
        else
        {
            Write-Host "No ID found for $packageName"
        }
    }
    $ProductIDs
}

function Get-Cookie ()
{
    $cookieXml = @"
<Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns="http://www.w3.org/2003/05/soap-envelope">
	<Header>
		<Action d3p1:mustUnderstand="1"
			xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope"
			xmlns="http://www.w3.org/2005/08/addressing">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/GetCookie</Action>
		<MessageID xmlns="http://www.w3.org/2005/08/addressing">urn:uuid:b9b43757-2247-4d7b-ae8f-a71ba8a22386</MessageID>
		<To d3p1:mustUnderstand="1"
			xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope"
			xmlns="http://www.w3.org/2005/08/addressing">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx</To>
		<Security d3p1:mustUnderstand="1"
			xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope"
			xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
			<Timestamp xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
				<Created>2017-12-02T00:16:15.210Z</Created>
				<Expires>2017-12-29T06:25:43.943Z</Expires>
			</Timestamp>
			<WindowsUpdateTicketsToken d4p1:id="ClientMSA"
				xmlns:d4p1="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
				xmlns="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
				<TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
					<user>{}</user>
				</TicketType>
			</WindowsUpdateTicketsToken>
		</Security>
	</Header>
	<Body>
		<GetCookie xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
			<oldCookie>
			</oldCookie>
			<lastChange>2015-10-21T17:01:07.1472913Z</lastChange>
			<currentTime>2017-12-02T00:16:15.217Z</currentTime>
			<protocolVersion>1.40</protocolVersion>
		</GetCookie>
	</Body>
</Envelope>
"@

    $cookieResponse = Invoke-RestMethod -Uri "https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx" -Method Post -ContentType "application/soap+xml" -Body $cookieXml
    $cookie = $cookieResponse.Envelope.Body.GetCookieResponse.GetCookieResult
    $cookie

}

#Takes: Object output from Get-UpdateIDs
#Returns: Hashtable of files by name and version
function Parse-FileName ($UpdateIDs)
{
    #Code for parsing package name
    #https://github.com/Andrew-J-Larson/OS-Scripts/blob/main/Windows/Wrapper-Functions/Download-AppxPackage-Function.ps1
    [Collections.Generic.Dictionary[string, Collections.Generic.Dictionary[string, array]]] $packageList = @{}
    $UpdateIDs | Where OSMinMet -eq $true | ForEach-Object { #Only get app where the OS meets the minimum install version
        $text = $_.Appname
        $textSplitUnderscore = $text.split('_')
        $name = $textSplitUnderscore.split('_')[0]
        $version = $textSplitUnderscore.split('_')[1]
        $arch = ($textSplitUnderscore.split('_')[2]).ToLower()
        $publisherId = $textSplitUnderscore.split('_')[4]

        # create $name hash key hashtable, if it doesn't already exist
        if (!($packageList.keys -match ('^' + [Regex]::escape($name) + '$'))) {
          $packageList["$name"] = @{}
        }
        # create $version hash key array, if it doesn't already exist
        if (!(($packageList["$name"]).keys -match ('^' + [Regex]::escape($version) + '$'))) {
          ($packageList["$name"])["$version"] = @()
        }
        
        # add package to the array in the hashtable
        ($packageList["$name"])["$version"] += @{
          filename    = $text
          name        = $name
          version     = $version
          arch        = $arch
          publisherId = $publisherId
          fileurl     = ""
          type        = $_.Filename.Substring($_.Filename.LastIndexOf('.'))
          updateId    = $_.UpdateID
          RevisionID  = $_.RevisionID
          FileSize    = $_.FileSize
          Dependencies = $_.Dependencies
        }
    }
    $PackageList
}


#Takes: Category ID and a cookie
#Returns: UpdateID, RevisionID, Filename from update server, file size, if the minimum OS version is met and if there are dependencies
function Get-UpdateIDs ($wuCategory, $cookie)
{
    $wuidRequestXml = $wuidRequestXml_original -replace '<Id>{wuCategoryId}</Id>',"<Id>$wuCategory</Id>"
    $wuidRequestXml = $wuidRequestXml -replace '<Expiration>{CookieExpiration}</Expiration>', "<Expiration>$($Cookie.Expiration)</Expiration>"
    $wuidRequestXml = $wuidRequestXml -replace '<EncryptedData>{CookieData}</EncryptedData>', "<EncryptedData>$($Cookie.EncryptedData)</EncryptedData>"

    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName System.Net.Http
    $client = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, "https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx")
    $request.Content = [System.Net.Http.StringContent]::new($wuidRequestXml, [System.Text.Encoding]::UTF8, "application/soap+xml")
    $httpResponse = $client.SendAsync($Request, [System.Threading.CancellationToken]::None).Result

    #This returns multiple files. Some files have a list of prerequisite update IDs included, but I've been unable to tie them to specific applications.
    #As far as I can tell, the other files are the dependencies/prereqs, so I will treat them as such.

    $content = $httpResponse.Content.ReadAsStringAsync().Result
    [xml]$decodedContent = [System.Web.HttpUtility]::HtmlDecode($content)
    $nodes = $decodedContent.GetElementsByTagName("SecuredFragment")

    $UpdateObject = [pscustomobject]@{
        UpdateID   = ""
        RevisionID = ""
        Filename = ""
        AppName = ""
        FileURL = ""
        FileType = ""
        FileSize = ""
        OSMinMet = ""
        Dependencies = @()
    }
    $OSVersion = [version](Get-CimInstance Win32_OperatingSystem).Version
    $UBR = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR).UBR
    $OSVersionEncoded = ([UInt64]$OSVersion.Major -shl 48) -bor ([UInt64]$OSVersion.Minor -shl 32) -bor ([UInt64]$OSVersion.Build -shl 16) -bor [UInt64]$UBR
    $UpdateIDs = @()
    $FileIDs = ($decodedContent.GetElementsByTagName("File") | Where -Filterscript {$_.FileName -Like "*.msi*" -or $_.FileName -Like "*.appx*"}).ParentNode.ParentNode.ParentNode
    foreach ($node in $nodes) #Parse the update information file for details about the update
    {
        $SecureFragmentID = $node.ParentNode.ParentNode.ParentNode.id
        $ID = $FileIDs | Where ID -eq $SecureFragmentID
        if ($ID -ne $null)
        {
            $UpdateObject.FileName = $($ID.xml.Files.file | Where -Filterscript {$_.FileName -Like "*.msi*" -or $_.FileName -Like "*.appx*"}).FileName
            $UpdateObject.AppName = $($ID.xml.Files.file | Where -Filterscript {$_.FileName -Like "*.msi*" -or $_.FileName -Like "*.appx*"}).InstallerSpecificIdentifier
            $UpdateObject.FileType = $UpdateObject.Filename.Substring($($Updateobject.filename.lastindexof('.')))
            $Filesize = $($ID.xml.Files.file | Where -Filterscript {$_.FileName -Like "*.msi*" -or $_.FileName -Like "*.appx*"}).ParentNode.ParentNode.ExtendedProperties.MaxDownloadSize
            $UpdateObject.FileSize =  "$($($Filesize/1048576).ToString('#.##')) MB"
            $ApplicabilityBlob = $decodedContent.GetElementsByTagName("AppxMetadata") | Where PackageMoniker -eq $UpdateObject.AppName | Select ApplicabilityBlob -ExpandProperty ApplicabilityBlob | ConvertFrom-Json
            $MinOSVersion = $ApplicabilityBlob.'content.targetPlatforms' | Where {$_.'platform.target' -eq 3 -or $_.'platform.target' -eq 0} | Sort-Object -Property 'platform.MinVersion' -Descending | Select 'platform.MinVersion' -ExpandProperty 'platform.MinVersion' -First 1
            #Platform.Target 3 and 0 are Windows.Desktop and Windows.Universal, respectively
            if ($OSVersionEncoded -ge $MinOSVersion) {$UpdateObject.OSMinMet = $true} else {$UpdateObject.OSMinMet = $false}
            
            $UpdateObject.UpdateID = $node.ParentNode.ParentNode.FirstChild.UpdateID
            $UpdateObject.RevisionID = $node.ParentNode.ParentNode.FirstChild.RevisionNumber
            if ($node.ParentNode.ParentNode.Relationships.Prerequisites -ne $null) {$UpdateObject.Dependencies = "Yes"}

            $UpdateIDs += $UpdateObject.psobject.Copy()
        }
    }
    $UpdateIDs
}

$architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
    "x86" { "x86" }
    { @("x64", "amd64") -contains $_ } { "x64" }
    "arm" { "arm" }
    "arm64" { "arm64" }
    default { "neutral" } # should never get here
  }


$UBR = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR).UBR
[version]$OSVersion = "$((Get-CimInstance Win32_OperatingSystem).Version)" + "." + $UBR

#Step 1: Get Product ID(s) from Microsoft Store
if ($SoftwareFamily -eq "") {$ProdID = Get-ProductID} else {$ProdID = Get-ProductID -PackageFamilyName $SoftwareFamily}

$UserInstallScript = ""
$Categories = @()
$global:ProgressPreference = 'SilentlyContinue'
$InstalledApps = Get-AppxPackage -AllUsers
$InstalledBundles = Get-AppxPackage -AllUsers -PackageTypeFilter Bundle
foreach ($ID in $ProdID)
{
    Write-Host "Processing $($ID.Name)"
    # Step 2: Get update Category ID
    Write-Verbose "Getting wuCategoryID for $($ID.ID)"
    $wuCategory = Get-wuCategoryID ($ID.ID)

    # Step 3: Obtain Cookie
    #https://github.com/LSPosed/MagiskOnWSALocal/blob/main/xml/GetCookie.xml
    $Cookie = Get-Cookie

    # Step 3: Send WUID Request, get full list of files, versions and dependencies
    #https://github.com/LSPosed/MagiskOnWSALocal/blob/main/xml/WUIDRequest.xml
    #https://github.com/LSPosed/MagiskOnWSALocal/blob/main/scripts/generateWSALinks.py
    Write-verbose "Getting UpdateIDs for $wuCategory"
    $UpdateID = Get-UpdateIDs $wuCategory -cookie $Cookie #Gives everything but the URL

    Write-verbose "Parsing filenames"
    $UpdateIDlist = Parse-FileName $UpdateID
    Write-verbose "Completed parsing"

    #Now we have a hashtable of unique packages based on what we checked for
    #It's possible that multiple architectures for a given package can be installed at the same time
    #We should iterate through our list and grab what's installed.

    Write-Verbose "Defining packages for update"

    $LatestPackages = @()
    $UpdateIDList.GetEnumerator() | ForEach-Object { $LatestPackages += (($_.value).GetEnumerator() | Sort-Object -Property key -Descending | Select -First 1).value}

    $RelevantAppNames = @()
    $LatestPackages | %{$RelevantAppNames += $_["name"]}
    $RelevantAppNames = $RelevantAppNames | Select -Unique

    #Get newest package version installed
    $NewestInstalledAppInfo = $InstalledApps | Where name -Match (Wildcard-toRegex $RelevantAppNames) | Select Name, Architecture, Version | Group-Object Name, Architecture | % {$_.Group | Sort-Object -Property Version -Descending | Select -First 1}
    $LatestPackagesList = $LatestPackages | %{[pscustomobject]$_}

    if (!(Get-Item $DownloadPath -ErrorAction SilentlyContinue)) {New-Item -Path $DownloadPath -ItemType Directory}
    if (!(Get-Item "$DownloadPath\DownloadList.txt" -Erroraction SilentlyContinue)) {New-Item "$DownloadPath\DownloadList.txt" -Force}
    $DownloadedList = Get-Content "$DownloadPath\DownloadList.txt"

    $Queuedforupdate = @()
    foreach ($Latest in $LatestPackagesList)
    {
        if ($Latest.type -like ".*bundle") {$NewestInstalledAppInfo = $InstalledBundles | Where name -Match (Wildcard-toRegex $RelevantAppNames) | Select Name, Architecture, Version | Group-Object Name, Architecture | % {$_.Group | Sort-Object -Property Version -Descending | Select -First 1}}
        foreach ($app in $NewestInstalledAppInfo)
        {
            if ($Latest.name -eq $app.name -and ($Latest.arch -eq $app.architecture -or $Latest.arch -eq "neutral"))
            {
                if ([System.Version]$app.Version -lt [System.Version]$Latest.version)
                    {
                        if (!($DownloadedList -like "*$($Latest.filename)$($Latest.type)"))
                        {
                            $Queuedforupdate += $Latest
                            Write-Host "$($Latest.name) $($Latest.arch) is queued for update"
                            Write-verbose "Installed: $($app.Version), Newest: $($Latest.Version)"
                        } else { Write-host "Already downloaded or queued for download" }
                    }
                else {
                    Write-Host "$($app.Name) $($app.architecture) is up to date"
                    Write-verbose "Version: $($Latest.Version)"
                    }
            }
        }
    }

    #Step 4: Get File URLs
    foreach ($Update in $QueuedforUpdate)
    {
        Write-verbose "Getting file URL for $($Update.filename)"

        $FE3XML = $FE3FileURLXML -replace '<UpdateID>.*?<\/UpdateID>',"<UpdateID>$($Update.UpdateID)</UpdateID>"
        $FE3XML = $FE3XML -replace '<RevisionNumber>.*?<\/RevisionNumber>',"<RevisionNumber>$($update.RevisionID)</RevisionNumber>"
        $FE3Response = Invoke-RestMethod -Uri "https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured" -Method Post -ContentType "application/soap+xml" -Body $FE3XML

        $Update.FileURL = $FE3Response.GetElementsByTagName("FileLocation") | Select URL -ExpandProperty URL | Where {$_.length -ne 99}
        #Avoids getting blockmap. https://github.com/StoreDev/StoreLib/blob/3f2a98ffede0bf3f78321c194e884fd0aaf14c29/StoreLib/Services/FE3Handler.cs#L139

    }

    #Select the main package (the one we searched for and not its dependencies)
    $MPackage = $Queuedforupdate | Where name -EQ $ID.Name
    foreach ($MainPackage in $Mpackage)
    {
        $Outfile = "$DownloadPath\$($MainPackage.filename)$($MainPackage.type)"
        $DownloadedList = Get-Content "$DownloadPath\DownloadList.txt"

        if (!($DownloadedList -like "*$($MainPackage.filename)$($MainPackage.type)"))
        {
            Write-host "Downloading to $Outfile `($($MainPackage.Filesize)`)"
            Invoke-WebRequest -Uri $MainPackage.fileurl -OutFile $Outfile -ErrorAction SilentlyContinue
            if (Get-item $Outfile -ErrorAction SilentlyContinue)
            {
                Write-Host "File downloaded successfully. Getting dependencies"
                #Get dependencies
                $Dependencies = Get-MSIXDependenciesFromFile -Path $Outfile
                "$($MainPackage.filename)$($MainPackage.type)" | Out-File "$DownloadPath\DownloadList.txt" -Append
                foreach ($Dep in $Dependencies.Package)
                {
                    if (!($InstalledApps | Where {$_.name -eq $Dep.name -and [version]$_.version -gt [version]$Dep.MinVersion})) #If dependency isn't already installed or is too old
                    {
                        #Download dependency
                        $Deptodownload = $LatestPackagesList | Where {$_.name -eq $dep.Name -and ($_.arch -eq $architecture -or $_.arch -eq "neutral") -and $_.version -ge $dep.minversion}
                        if ($Deptodownload -ne $null)
                        {
                            $FE3XML = $FE3FileURLXML -replace '<UpdateID>.*?<\/UpdateID>',"<UpdateID>$($Deptodownload.UpdateID)</UpdateID>"
                            $FE3XML = $FE3XML -replace '<RevisionNumber>.*?<\/RevisionNumber>',"<RevisionNumber>$($Deptodownload.RevisionID)</RevisionNumber>"
                            try{
                            $FE3Response = Invoke-RestMethod -Uri "https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured" -Method Post -ContentType "application/soap+xml" -Body $FE3XML
                            } catch {
                            Write-host "Get URL Failed"
                            }
                            $URL = $FE3Response.GetElementsByTagName("FileLocation") | Select URL -ExpandProperty URL | Where {$_.length -ne 99}

                            $Outfile = "$DownloadPath\$($Deptodownload.filename)$($Deptodownload.type)"
                            $DownloadedList = Get-Content "$DownloadPath\DownloadList.txt"
                            if (!($DownloadedList -like "*$($Deptodownload.filename)$($Deptodownload.type)"))
                            {
                                Write-host "Downloading dependency to $Outfile `($($Deptodownload.Filesize)`)"
                                "$($Deptodownload.filename)$($Deptodownload.type)" | Out-File "$DownloadPath\DownloadList.txt" -Append
                                "$($Deptodownload.filename)$($Deptodownload.type)" | Out-File "$DownloadPath\Dependencies.txt" -Append
                                Invoke-WebRequest -Uri $url -OutFile $Outfile -ErrorAction SilentlyContinue
                                if (Get-item $Outfile -ErrorAction SilentlyContinue)
                                {
                                    Write-Host "File downloaded successfully"
                                } else {
                                    Write-Host "File download failed."
                                    }
                            } else { Write-Host "File $Outfile already present or queued for download, skipping download." }
                        }
                    } else {Write-Host "Dependency meeting requirements ($($dep.name) version $($dep.minversion)) not found on machine or available for download"}
                }
                Write-Host "Finished parsing dependencies"
            } else { Write-Host "File download failed" }
    }else { Write-Host "File $Outfile already present or queued for download, skipping download." }
  }
}

#Install the packages
if ($Install -eq $true -and (Get-Content -Path "$DownloadPath\DownloadList.txt" -ErrorAction SilentlyContinue))
{
    $DownloadedList = Get-Content "$DownloadPath\DownloadList.txt"
    $InstallList = Get-ChildItem -Path "$DownloadPath\*" -Include $DownloadedList | Select Fullname
    $InstallList | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name IsDependency -Value $false -Force}
    if (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -expand UserName) {$UserLoggedIn = $true}else {$UserLoggedIn = $false}
    if (Get-item -Path "$DownloadPath\Dependencies.txt" -ErrorAction SilentlyContinue)
    {
        $Dependencies = Get-Content "$DownloadPath\Dependencies.txt" | Select -Unique
        $UserInstallScript += ""
        foreach ($dep in $Dependencies)
        {
            $DependencyPath = $InstallList | Where {$_.FullName -like "*$dep*"}
            foreach ($DepPath in $DependencyPath)
            {
                ($InstallList | Where {$_.FullName -like "*$($DepPath.fullname)*"}).IsDependency = $true
                try {
                    Write-Host "Installing dependency $($DepPath.FullName)"
                    Add-AppxPackage -Path $DepPath.Fullname -Stage -ForceUpdateFromAnyVersion
                    if ($UserLoggedIn -eq $true)
                    {
                        $UserInstallScript += "Add-AppxPackage -Path `"$($DepPath.Fullname)`" -ForceApplicationShutdown -ForceUpdateFromAnyVersion`n"
                    }
                } catch {
                    Write-Warning "Dependency package $($DepPath.Fullname) failed to install with error message: $($Error[0].Exception)."
                }
            }
        }
    }

    foreach ($Install in $InstallList | Where IsDependency -eq $false)
    {
        try {
            Write-Host "Installing package $($Install.Fullname)"
            Add-AppxPackage -Path $Install.Fullname -Stage -ForceUpdateFromAnyVersion
            if ($UserLoggedIn -eq $true)
            {
                $UserInstallScript += "Add-AppxPackage -Path `"$($Install.Fullname)`" -ForceApplicationShutdown -ForceUpdateFromAnyVersion `n"
            }
        } catch { Write-Warning "Package $($Install.Fullname) failed to install with error message: $($Error[0].Exception)." }
    }


    #If a user is logged in, install the apps on their account
    if ($UserLoggedIn -eq $true)
    {
        $SessionList = quser 2>$null
        $UserInfo = foreach ($Session in ($SessionList | select -Skip 1)) {
            $Session = $Session.ToString().trim() -replace '\s+', ' ' -replace '>', ''
            if ($Session.Split(' ')[3] -eq 'Active') {
                [PSCustomObject]@{
                    UserName     = $session.Split(' ')[0]
                    SessionName  = $session.Split(' ')[1]
                    SessionID    = $Session.Split(' ')[2]
                    SessionState = $Session.Split(' ')[3]
                    IdleTime     = $Session.Split(' ')[4]
                    LogonTime    = $session.Split(' ')[5, 6, 7] -as [string] -as [datetime]
                }
            } else {
                [PSCustomObject]@{
                    UserName     = $session.Split(' ')[0]
                    SessionName  = $null
                    SessionID    = $Session.Split(' ')[1]
                    SessionState = 'Disconnected'
                    IdleTime     = $Session.Split(' ')[3]
                    LogonTime    = $session.Split(' ')[4, 5, 6] -as [string] -as [datetime]
                }
            }
        }
        $UserInstallScript = $UserInstallScript.TrimEnd("`n")
        #"conhost --headless powershell" is used to help ensure the window stays hidden
        $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\conhost.exe" -Argument "--headless powershell -WindowStyle hidden -NoProfile -NonInteractive -ExecutionPolicy Bypass -command `"$UserInstallScript`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        foreach ($User in $Userinfo)
        {
            Write-Host "Creating user-level install for $($User.Username)"
            $Taskname = "UserAppInstall_" + $User.Username
            $UserDomain = (Get-CimInstance -ClassName Win32_LoggedOnUser).Antecedent | Where name -EQ $User.Username | Select Domain -ExpandProperty Domain
            $UserID = "$Userdomain\$($user.Username)"

            $principal = New-ScheduledTaskPrincipal -UserId $UserID
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
            Register-ScheduledTask $Taskname -InputObject $task
            Start-ScheduledTask -TaskName $Taskname
            While ((Get-ScheduledTask -TaskName $Taskname).State -eq "Running")
            {
                Sleep -Seconds 5
            }
            Unregister-ScheduledTask -TaskName $Taskname -TaskPath "\" -Confirm:$false
        }
    }

    Write-host "Cleaning up downloaded packages"
    $DownloadedList = Get-Content "$DownloadPath\DownloadList.txt"
    foreach ($Update in $DownloadedList)
    {
        $Outfile = "$DownloadPath\$Update"
        Remove-Item -Path $Outfile -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-item "$DownloadPath\Downloadlist.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-item "$DownloadPath\Dependencies.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue
}


Stop-Transcript