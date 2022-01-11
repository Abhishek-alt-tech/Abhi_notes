import java.text.SimpleDateFormat; 
 import org.apache.commons.codec.digest.DigestUtils;
import java.io.FileInputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
def startDate 
def endDate 
 def fileContents 
def md5 
def projectId= "485" 
def projectName= "CENTRALIZEDVENDOR" 
def moduleId= "291" 
def moduleName= "CENTRALIZED VENDOR TIE UP DHL DASHBOARD_IT-ATM" 
def newBuildId= "3.0.0.${BUILD_ID}" 
def sonarUrl= "https://sonarqubepreprod.statebanktimes.in" 
def tomcatCredIdForJenkins= "tomcat" 
def tomcatServer= "https://devopsservicespreprod.statebanktimes.in" 

def CODE =  readJSON text: '{"url":"https://gitlabpreprod.statebanktimes.in/root/centralizedvendor.git","scm":"gitlab","branch":"master","credId":"gitlab"}'
def UNITTEST =  readJSON text: '{"command":"mvn test"}'
def BUILD =  readJSON text: '{"command":"mvn package"}'
def ANALYSIS =  readJSON text: '{"sonarkey":"centralizedvendor"}'
def BINARY =  readJSON text: '{"url":"https://nexuspreprod.statebanktimes.in/"}'
def DEPLOYMENT =  readJSON text: '{"contextPath":"CENTRALIZEDVENDOR"}'

pipeline {
agent any
options {
skipDefaultCheckout()
 }
	stages {

		stage('CODE'){
		        steps{
		        script{
					buildName newBuildId
				}
		            git url: CODE.url, credentialsId: CODE.credId, branch: CODE.branch
		        }

		}
		stage('UNIT-TEST'){
		      steps{
		            println "Test code ..."
		            executeCmd("/opt/apache-maven-3.6.3/bin/"+UNITTEST.command);
		         }
		}
		stage('Build'){
		       steps{
		       script{
		       startDate = new Date()
		       }
		       		println "Building code ...."
		            executeCmd("/opt/apache-maven-3.6.3/bin/"+BUILD.command);
		         //  //script{
		            
		           // //println "artifact code ....${IMAGE}"
		           //// fileContents = "/var/lib/jenkins/workspace/${JOB_NAME}/target/${IMAGE}.war"
		           // fileContents ='target/*.war'
		           //	println "Building code ....${fileContents}"
		          	////md5 =  DigestUtils.md5Hex(new FileInputStream(fileContents));

		               			// MessageDigest digest = MessageDigest.getInstance("MD5") ;
		                //	println "Building code ....${digest}"
		               // digest.update(fileContents.bytes); 
		                //	println "Building code ....2"
		               // md5 = new BigInteger(1, digest.digest()).toString(16).padLeft(32, '0') ;    
                	////println "Building code ....${md5}"
                    ////}
	            	                     
		       }
			   post{
				   always{
					   script{
					   	endDate = new Date()
					    	    			adoptBuildFeedback buildDisplayName: "${projectName}.${newBuildId}",
		    			 					buildEndedAt: "${endDate}",
		    			 					buildStartedAt: "${startDate}",
		    								buildUrl: "${BUILD_URL}", 
		    			   					projectId: projectId,
		    			    				status: "${currentBuild.currentResult}",
		    			    				buildHashValue: "${md5}"
		    			    				
					   }
				   }
				   
			   }
		}
	stage('SonarQube analysis') {
			steps {
				println "Building code ..."
				withSonarQubeEnv('SonarQube') {
					executeCmd("/opt/apache-maven-3.6.3/bin/mvn sonar:sonar"+" "+"-Dsonar.host.url="+ sonarUrl +" "+"-Dsonar.projectKey="+ANALYSIS.sonarkey);
					
				}
				 executeCmd("sleep 10") 
				 timeout(time: 1, unit: 'HOURS') {
					waitForQualityGate abortPipeline: true
				}
			}
			post{
			   success{
				   script{
					 adoptCodeAnalysisFeedback  buildDisplayName: "${projectName}.${newBuildId}",
					 							buildUrl: "${BUILD_URL}",
					 							sonarKey: "${ANALYSIS.sonarkey}",
					 							projectId: "${projectId}"
				   }
			   }
			 }
		   }
		stage('Binary Management'){
		       steps{
		             println "Uploading packaged code ..."
		             script{
						withCredentials([usernamePassword(credentialsId: 'nexus_admin', passwordVariable: 'password', usernameVariable: 'username')]) {
						sh "curl -v -u ${username}:${password} --upload-file  target/*.war 'https://nexuspreprod.statebanktimes.in/repository/jenkins_rel/${moduleName.replaceAll("\\s+","-")}/${projectName}/${projectName}.${newBuildId}.war'"
				
				}
		  }
		             
		}
		}
		stage('Deployment'){
			             steps{               
		                    deploy adapters: [tomcat9(credentialsId: tomcatCredIdForJenkins,
		                            path: '', url: tomcatServer)],
		                            contextPath: DEPLOYMENT.contextPath,
		                            onFailure: true,
		                            war: 'target/*.war'
		            }
		            post{
		                always{
		                
		                mail to: 'devops_platform_rcv@mocksmtp.com',
               			subject: "Status of pipeline: ${currentBuild.fullDisplayName}",
               			body: "${env.BUILD_URL} has result ${currentBuild.result}"
               			
								script{
						   				startDate = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(new Date())
                                        adoptDevDeploymentFeedback buildDisplayName: "${projectName}.${newBuildId}",
                                         							deploymentStartedAt: "${startDate}", 
                                       								environment: "DEV",
                                          							moduleId: moduleId, 
                                          							moduleName: "${moduleName}",
                                           							projectName: "${projectName}",
                                            						status: "${currentBuild.currentResult}"

								}
							}
					
		                   
		            }
			
		}
		stage('Performance Testing'){
		                   steps{ 
                      						   
		                   sh '/opt/apache-jmeter-5.4/bin/jmeter -Jjmeter.save.saveservice.output_format=xml -n -t /opt/apache-jmeter-5.4/bin/BeanShellSampler.jmx -l /home/jmeter_report/TestResult1.jtl'
						   perfReport filterRegex: '', sourceDataFiles: '/home/jmeter_report/TestResult1.jtl'
		            }
		
		}
	

	}
}

//Helper Methods

void executeCmd(String CMD){
	if(isUnix()){
		sh "echo linux"
		sh CMD
	}
	else{
		 bat "echo windows"
		 bat CMD
	}
}
