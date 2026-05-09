import React from 'react';
import { AlertCircle } from 'lucide-react';

/**
 * Standard Medical Disclaimer for AmbyoAI.
 * Required for clinical-grade transparency.
 */
const MedicalDisclaimer = ({ className = "" }) => {
  return (
    <div className={`p-4 bg-amber-50 border border-amber-200 rounded-xl flex gap-3 text-amber-900 shadow-sm ${className}`}>
      <div className="shrink-0 text-amber-600 mt-0.5">
        <AlertCircle size={20} />
      </div>
      <div className="text-sm leading-relaxed font-medium">
        AmbyoAI is an AI-assisted screening and referral support tool. 
        It does <strong>not</strong> provide a final medical diagnosis. 
        Final interpretation and treatment decisions must be confirmed by a 
        qualified ophthalmologist or optometrist.
      </div>
    </div>
  );
};

export default MedicalDisclaimer;
